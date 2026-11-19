import { HttpStatus } from '@nestjs/common';

/**
 * Traducción de errores de PostgreSQL a respuestas que el usuario entiende.
 *
 * Postgres devuelve en el error un SQLSTATE (`code`) y, cuando aplica, la
 * constraint que lo disparó. Antes solo se traducía `P0001` y todo lo demás
 * salía como «Error interno del servidor» (500), que no dice qué corregir.
 * Ver docs/RESPUESTA-REVISION-PREVENTIVA.md §1.
 */

export interface PgErrorLike {
  code: string;
  message: string;
  constraint?: string;
  detail?: string;
  table?: string;
  column?: string;
}

export interface PgErrorTraducido {
  status: HttpStatus;
  message: string;
}

/**
 * SQLSTATE que las funciones de negocio usan con `RAISE EXCEPTION` y cuyo
 * mensaje está escrito para el usuario: se devuelve tal cual.
 * - `P0001`: `RAISE EXCEPTION` sin ERRCODE.
 * - `22023`: `RAISE … USING ERRCODE = '22023'` (pagos de venta, recargas,
 *   cuentas bancarias, abono por NC).
 */
const CODIGOS_MENSAJE_FUNCION: ReadonlySet<string> = new Set([
  'P0001',
  '22023',
]);

/**
 * Mensaje específico por constraint. Solo las que puede disparar un usuario al
 * escribir un dato; las internas (correlativos, intentos de envío) caen al
 * mensaje genérico de su código.
 */
export const MENSAJES_CONSTRAINT: Readonly<Record<string, string>> = {
  // Configuración
  gen_condicion_pago_codigo_key:
    'Ya existe una condición de pago con ese código. Usa otro, por ejemplo CRED21.',
  gen_sucursal_codigo_key: 'Ya existe una sucursal con ese código.',
  gen_configuracion_servicio_codigo_key:
    'Ya existe un servicio con ese código.',
  gen_licencia_codigo_key: 'Ya existe una licencia con ese código.',
  gen_empresa_ruc_key: 'Ya existe una empresa registrada con ese RUC.',
  gen_clasificacion_gasto_grupo_subgrupo_sub_subgrupo_key:
    'Esa clasificación de gasto ya existe.',
  idx_gen_vehiculo_placa_empresa:
    'Ya existe un vehículo de la empresa con esa placa.',
  idx_gen_vehiculo_placa_cliente:
    'Ese cliente ya tiene un vehículo con esa placa.',
  // Maestros
  cli_clientes_numero_documento_key:
    'Ya existe un cliente con ese número de documento.',
  cli_clientes_codigo_interno_key:
    'Ya existe un cliente con ese código interno.',
  pro_producto_codigo_key: 'Ya existe un producto con ese código.',
  bal_balon_codigo_balon_key: 'Ya existe un balón con ese código.',
  auth_usuarios_correo_key: 'Ya existe un usuario con ese correo.',
  // Operación
  uq_fin_caja_sesion_fecha_sucursal:
    'Ya existe una caja para esa fecha y sucursal. Recarga la pantalla.',
  bal_alquiler_numero_alquiler_key:
    'Ese número de alquiler ya se usó. Recarga la pantalla e inténtalo de nuevo.',
  bal_prestamo_numero_prestamo_key:
    'Ese número de préstamo ya se usó. Recarga la pantalla e inténtalo de nuevo.',
  ven_comprobante_serie_numero_key:
    'Esa serie y número ya están registrados. Recarga la pantalla e inténtalo de nuevo.',
  uq_doc_salida_numero:
    'Ese número de documento de salida ya se usó. Recarga la pantalla e inténtalo de nuevo.',
  uq_doc_salida_empresa_serie_numero:
    'Esa serie y número de guía ya están registrados. Recarga la pantalla e inténtalo de nuevo.',
};

const MENSAJES_CODIGO: Readonly<Record<string, PgErrorTraducido>> = {
  '23505': {
    status: HttpStatus.CONFLICT,
    message:
      'Ya existe un registro con ese dato. Revisa el código o número ingresado.',
  },
  '23502': {
    status: HttpStatus.BAD_REQUEST,
    message: 'Falta completar un campo obligatorio.',
  },
  '23514': {
    status: HttpStatus.BAD_REQUEST,
    message: 'Uno de los valores está fuera del rango permitido.',
  },
  '22P02': {
    status: HttpStatus.BAD_REQUEST,
    message:
      'Un dato tiene un formato inválido (por ejemplo, texto donde va un número).',
  },
  '22003': {
    status: HttpStatus.BAD_REQUEST,
    message: 'Un número es demasiado grande para el campo.',
  },
  '22001': {
    status: HttpStatus.BAD_REQUEST,
    message: 'Un texto es más largo de lo permitido para el campo.',
  },
  '22007': {
    status: HttpStatus.BAD_REQUEST,
    message: 'Una fecha tiene un formato inválido.',
  },
  '22008': {
    status: HttpStatus.BAD_REQUEST,
    message: 'Una fecha u hora está fuera de rango.',
  },
  '40001': {
    status: HttpStatus.CONFLICT,
    message:
      'Otro usuario modificó estos datos al mismo tiempo. Vuelve a intentarlo.',
  },
  '40P01': {
    status: HttpStatus.CONFLICT,
    message:
      'Otro usuario modificó estos datos al mismo tiempo. Vuelve a intentarlo.',
  },
  '55P03': {
    status: HttpStatus.CONFLICT,
    message:
      'El registro está siendo modificado por otro usuario. Vuelve a intentarlo.',
  },
};

export function esPgError(
  exception: unknown,
): exception is Error & PgErrorLike {
  if (!(exception instanceof Error)) return false;
  const code = (exception as { code?: unknown }).code;
  // SQLSTATE: 5 caracteres alfanuméricos. Evita confundir códigos de otros
  // errores de Node (ECONNREFUSED, ERR_…) con errores de la base.
  return typeof code === 'string' && /^[0-9A-Z]{5}$/.test(code);
}

/**
 * Devuelve la traducción del error o `null` si debe seguir siendo 500
 * (errores de sistema: conexión, sintaxis SQL, función inexistente, etc.).
 */
export function traducirPgError(error: PgErrorLike): PgErrorTraducido | null {
  const mensajeFuncion = error.message?.trim();

  if (CODIGOS_MENSAJE_FUNCION.has(error.code)) {
    return mensajeFuncion
      ? { status: HttpStatus.BAD_REQUEST, message: mensajeFuncion }
      : null;
  }

  // Un 23514 sin constraint viene de `RAISE … USING ERRCODE = '23514'` en un
  // trigger de negocio (p. ej. numeración bloqueada): su mensaje es para el
  // usuario. Un CHECK real siempre trae el nombre de la constraint.
  if (error.code === '23514' && !error.constraint && mensajeFuncion) {
    return { status: HttpStatus.BAD_REQUEST, message: mensajeFuncion };
  }

  if (error.code === '23503') {
    // El texto de `detail` distingue el caso: al borrar/actualizar un registro
    // referenciado dice «is still referenced»; al insertar con una referencia
    // inexistente dice «is not present».
    const enUso = /still referenced/i.test(error.detail ?? '');
    return enUso
      ? {
          status: HttpStatus.CONFLICT,
          message:
            'No se puede eliminar o cambiar: hay registros que dependen de este.',
        }
      : {
          status: HttpStatus.BAD_REQUEST,
          message:
            'Uno de los datos seleccionados ya no existe o fue dado de baja. Recarga la pantalla.',
        };
  }

  const porCodigo = MENSAJES_CODIGO[error.code];
  if (!porCodigo) return null;

  const porConstraint = error.constraint
    ? MENSAJES_CONSTRAINT[error.constraint]
    : undefined;
  return porConstraint ? { ...porCodigo, message: porConstraint } : porCodigo;
}
