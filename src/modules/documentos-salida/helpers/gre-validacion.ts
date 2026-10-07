import { documentoSunatValido, fechaCivilSunat, normalizarCodigoSunat, normalizarDocumentoSunat, tipoDocumentoSunat } from '../../../common/helpers/sunat-datos.helper';
import type {
  DocumentoSalidaRegistro,
  EmpresaEmisora,
  GreProblema,
} from '../interfaces/documento-salida.interface';

/**
 * Prevalidación única de la GRE: la usan el endpoint `validar-gre` (para
 * mostrar problemas junto al campo antes de enviar) y el mapper justo antes de
 * armar el payload, así no hay diferencias entre lo que la pantalla acepta y
 * lo que el envío exige.
 *
 * Es una función pura: no consulta base de datos ni al PSE. Lo que dependa del
 * proveedor (entorno, credenciales) se valida aparte en la lógica de emisión.
 */

const RE_UBIGEO = /^\d{6}$/;
const RE_RUC = /^\d{11}$/;
const RE_PLACA = /^[A-Z0-9]{6,7}$/;
const RE_LICENCIA = /^[A-Z0-9]{1,10}$/;

export interface ContextoValidacionGre {
  /** Fecha de hoy en Lima (YYYY-MM-DD); inyectable para pruebas. */
  hoy?: string;
}

/** Fecha civil de Lima (UTC-5, sin horario de verano). */
export function hoyLima(now = new Date()): string {
  return new Date(now.getTime() - 5 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

export function normalizarPlaca(placa?: string | null): string {
  return normalizarLicencia(placa);
}

/** Quita solo separadores de presentación; conserva letras, números y ceros iniciales. */
export function normalizarLicencia(licencia?: string | null): string {
  return (licencia ?? '').replace(/[\s\-\u2010-\u2015\u2212]/g, '').toUpperCase();
}

function texto(value?: string | null): string {
  return (value ?? '').trim();
}

function fecha(value?: string | null): string | null {
  return fechaCivilSunat(value);
}

/** Comparte el destinatario real entre la prevalidación y el envío. */
export function destinatarioGre(cabecera: DocumentoSalidaRegistro) {
  const proveedor = { doc: normalizarDocumentoSunat(cabecera.documento_proveedor), nombre: texto(cabecera.nombre_proveedor), tipoDocumento: null as string | null | undefined };
  const destinatario = { doc: normalizarDocumentoSunat(cabecera.documento_destinatario), nombre: texto(cabecera.nombre_destinatario), tipoDocumento: cabecera.nombre_tipo_doc_destinatario };
  const cliente = { doc: normalizarDocumentoSunat(cabecera.documento_cliente), nombre: texto(cabecera.nombre_cliente), tipoDocumento: cabecera.nombre_tipo_doc_cliente };
  const orden = cabecera.nombre_tipo_orden === 'RECARGA_PLANTA_EXTERNA'
    ? [proveedor, destinatario, cliente] : [destinatario, cliente, proveedor];
  return orden.find((c) => c.doc && (normalizarCodigoSunat(cabecera.codigo_tipo_guia) !== '31' || c !== cliente));
}

/** Nombres y apellidos del chofer, ya estructurados o partidos como último recurso. */
export function nombresChofer(cabecera: Pick<
  DocumentoSalidaRegistro,
  'nombres_chofer' | 'apellido_paterno_chofer' | 'apellido_materno_chofer' | 'nombre_chofer'
>): { nombres: string; apellidos: string; estructurado: boolean } {
  const nombres = texto(cabecera.nombres_chofer);
  const apellidos = [texto(cabecera.apellido_paterno_chofer), texto(cabecera.apellido_materno_chofer)]
    .filter(Boolean)
    .join(' ');
  if (nombres && apellidos) return { nombres, apellidos, estructurado: true };

  const parts = texto(cabecera.nombre_chofer).split(/\s+/).filter(Boolean);
  if (parts.length === 0) return { nombres: '', apellidos: '', estructurado: false };
  if (parts.length === 1) return { nombres: parts[0], apellidos: parts[0], estructurado: false };
  return { nombres: parts[0], apellidos: parts.slice(1).join(' '), estructurado: false };
}

/** Si el traslado va con flota propia (vehículo + chofer) o con un tercero. */
export function esFlotaPropia(cabecera: Pick<DocumentoSalidaRegistro, 'codigo_tipo_guia' | 'codigo_modalidad_traslado'>): boolean {
  // La GRE transportista (31) la emite quien transporta: siempre lleva su
  // vehículo y su chofer, sin importar la modalidad guardada.
  if (normalizarCodigoSunat(cabecera.codigo_tipo_guia) === '31') return true;
  return normalizarCodigoSunat(cabecera.codigo_modalidad_traslado ?? '02') === '02';
}

export function validarGre(
  cabecera: DocumentoSalidaRegistro,
  empresa: EmpresaEmisora | null,
  contexto: ContextoValidacionGre = {},
): GreProblema[] {
  const problemas: GreProblema[] = [];
  const error = (codigo: string, campo: string, mensaje: string) =>
    problemas.push({ codigo, campo, mensaje, severidad: 'error' });
  const advertencia = (codigo: string, campo: string, mensaje: string) =>
    problemas.push({ codigo, campo, mensaje, severidad: 'advertencia' });
  const hoy = contexto.hoy ?? hoyLima();

  // --- Empresa emisora y domicilio fiscal ---
  if (!empresa) {
    error('EMPRESA_AUSENTE', 'empresa', 'La guía no tiene empresa emisora vinculada');
  } else {
    if (!RE_RUC.test(normalizarDocumentoSunat(empresa.ruc))) {
      error('EMPRESA_RUC', 'empresa.ruc', 'El RUC de la empresa emisora debe tener 11 dígitos');
    }
    if (!texto(empresa.razon_social) && !texto(empresa.nombre_comercial)) {
      error('EMPRESA_RAZON_SOCIAL', 'empresa.razon_social', 'Registra la razón social de la empresa emisora');
    }
    if (!texto(empresa.direccion)) {
      error('EMPRESA_DIRECCION', 'empresa.direccion', 'Registra la dirección fiscal de la empresa emisora');
    }
    if (!RE_UBIGEO.test(texto(empresa.codigo_ubigeo))) {
      error(
        'EMPRESA_UBIGEO',
        'empresa.id_distrito',
        'Registra el distrito fiscal (ubigeo) de la empresa emisora en Configuración → Empresa',
      );
    }
  }

  // --- Tipo, serie y correlativo ---
  const tipo = texto(cabecera.codigo_tipo_guia);
  if (!['09', '31'].includes(tipo)) {
    error('TIPO_GUIA', 'idTipoGuiaRemision', `Tipo de guía ${tipo || '—'} no soportado para emisión electrónica`);
  }
  const serie = texto(cabecera.serie).toUpperCase();
  if (!serie) {
    error('SERIE_AUSENTE', 'serie', 'La guía no tiene serie asignada');
  } else if (tipo === '09' && !/^T\d{3}$/.test(serie)) {
    error('SERIE_TIPO', 'serie', 'La guía remitente (09) usa series T001–T999');
  } else if (tipo === '31' && !/^V\d{3}$/.test(serie)) {
    error('SERIE_TIPO', 'serie', 'La guía transportista (31) usa series V001–V999');
  }
  if (!texto(cabecera.numero_sunat)) {
    error('CORRELATIVO', 'numero_sunat', 'La guía no tiene correlativo SUNAT; conviértela a guía de remisión primero');
  } else if (!/^\d+$/.test(texto(cabecera.numero_sunat)) || !Number.isSafeInteger(Number(cabecera.numero_sunat)) || Number(cabecera.numero_sunat) < 1) {
    error('CORRELATIVO', 'numero_sunat', `Número SUNAT inválido: ${cabecera.numero_sunat}`);
  }

  // --- Fechas (zona horaria de Lima) ---
  const fechaEmision = fecha(cabecera.fecha_emision_gre);
  const fechaTraslado = fecha(cabecera.fecha_traslado);
  if (!fechaEmision) {
    error('FECHA_EMISION', 'fechaEmisionGre', 'Indica la fecha de emisión de la GRE');
  } else if (fechaEmision > hoy) {
    error('FECHA_EMISION_FUTURA', 'fechaEmisionGre', 'La fecha de emisión de la GRE no puede ser posterior a hoy');
  } else if (fechaEmision < hoy) {
    advertencia(
      'FECHA_EMISION_ANTERIOR',
      'fechaEmisionGre',
      `La fecha de emisión (${fechaEmision}) no es la de hoy (${hoy}); SUNAT puede rechazarla por fecha (código 2108)`,
    );
  }
  if (!fechaTraslado) {
    error('FECHA_TRASLADO', 'fechaTraslado', 'Indica la fecha de inicio del traslado');
  } else if (fechaEmision && fechaTraslado < fechaEmision) {
    error('FECHA_TRASLADO_ANTERIOR', 'fechaTraslado', 'El traslado no puede iniciar antes de la fecha de emisión de la GRE');
  }

  // --- Motivo, origen y destino ---
  if (!texto(cabecera.codigo_motivo_traslado)) {
    error('MOTIVO', 'idMotivoTraslado', 'Selecciona el motivo del traslado');
  }
  if (!texto(cabecera.direccion_origen)) {
    error('ORIGEN_DIRECCION', 'direccionOrigen', 'Indica la dirección del punto de partida');
  }
  if (!RE_UBIGEO.test(texto(cabecera.ubigeo_origen))) {
    error('ORIGEN_UBIGEO', 'idDistritoOrigen', 'El punto de partida requiere distrito con código ubigeo');
  }
  if (!texto(cabecera.direccion_llegada)) {
    error('LLEGADA_DIRECCION', 'direccionLlegada', 'Indica la dirección del punto de llegada');
  }
  if (!RE_UBIGEO.test(texto(cabecera.ubigeo_llegada))) {
    error('LLEGADA_UBIGEO', 'idDistritoLlegada', 'El punto de llegada requiere distrito con código ubigeo');
  }

  // --- Bienes ---
  const detalles = cabecera.detalle ?? [];
  if (detalles.length === 0) {
    error('SIN_ITEMS', 'detalle', 'El documento no tiene ítems');
  }
  detalles.forEach((detalle, index) => {
    if (!Number.isFinite(Number(detalle.cantidad)) || !(Number(detalle.cantidad) > 0)) {
      error('ITEM_CANTIDAD', `detalle.${index}.cantidad`, `La línea ${index + 1} debe tener cantidad mayor a 0`);
    }
    if (!texto(detalle.glosa) && !texto(detalle.descripcion) && !texto(detalle.nombre_producto)) {
      error('ITEM_DESCRIPCION', `detalle.${index}.descripcion`, `La línea ${index + 1} no tiene descripción`);
    }
  });
  if (!Number.isFinite(Number(cabecera.peso_bruto)) || !(Number(cabecera.peso_bruto) > 0)) {
    error('PESO', 'pesoBruto', 'Indica el peso bruto total (mayor a 0)');
  }
  if (cabecera.numero_bultos != null && (!Number.isSafeInteger(Number(cabecera.numero_bultos)) || !(Number(cabecera.numero_bultos) >= 1))) {
    error('BULTOS', 'numeroBultos', 'El número de bultos debe ser un entero de 1 o más');
  }

  // --- Destinatario / remitente ---
  const validarDocumento = (doc: string, tipoRegistrado: string | null | undefined, codigo: string, campo: string, etiqueta: string) => {
    try {
      if (!documentoSunatValido(doc, tipoDocumentoSunat(tipoRegistrado, doc))) {
        error(codigo, campo, `El documento del ${etiqueta} no corresponde al tipo registrado. Revisa el número y el tipo de documento.`);
      }
    } catch {
      error(codigo, campo, `Selecciona el tipo de documento del ${etiqueta}; no se puede deducir del número registrado.`);
    }
  };
  const destinatario = destinatarioGre(cabecera);
  const destinatarioDoc = destinatario?.doc;
  if (!destinatarioDoc) {
    error('DESTINATARIO_DOC', 'idDestinatario', 'El destinatario no tiene número de documento');
  } else {
    validarDocumento(destinatarioDoc, destinatario?.tipoDocumento, 'DESTINATARIO_DOC', 'idDestinatario', 'destinatario');
  }
  if (tipo === '31' && !texto(cabecera.documento_cliente)) {
    error('REMITENTE_DOC', 'idCliente', 'La GRE transportista (31) requiere remitente con documento');
  } else if (tipo === '31') {
    validarDocumento(normalizarDocumentoSunat(cabecera.documento_cliente), cabecera.nombre_tipo_doc_cliente, 'REMITENTE_DOC', 'idCliente', 'remitente');
  }

  // --- Transporte ---
  const flotaPropia = esFlotaPropia(cabecera);
  if (flotaPropia) {
    const placa = normalizarPlaca(cabecera.placa_vehiculo);
    if (!placa) {
      error('PLACA', 'idVehiculo', 'El transporte con flota propia requiere placa del vehículo');
    } else if (!RE_PLACA.test(placa)) {
      error('PLACA_FORMATO', 'idVehiculo', `La placa ${cabecera.placa_vehiculo} no tiene un formato válido para SUNAT`);
    }
    if (!cabecera.id_chofer && !texto(cabecera.documento_chofer)) {
      error('CHOFER', 'idChofer', 'El transporte con flota propia requiere chofer');
    } else {
      if (!texto(cabecera.documento_chofer)) {
        error('CHOFER_DOC', 'idChofer', 'El chofer no tiene número de documento');
      } else {
        validarDocumento(normalizarDocumentoSunat(cabecera.documento_chofer), cabecera.codigo_tipo_doc_chofer, 'CHOFER_DOC', 'idChofer', 'chofer');
      }
      const licencia = normalizarLicencia(cabecera.licencia_chofer);
      if (!licencia) {
        error('CHOFER_LICENCIA', 'idChofer', 'El chofer seleccionado no tiene licencia activa registrada');
      } else {
        if (!RE_LICENCIA.test(licencia)) {
          error('CHOFER_LICENCIA_FORMATO', 'idChofer', 'La licencia del conductor debe contener solo letras y números, con un máximo de 10 caracteres. Revisa el número en Configuración → Choferes → Licencias. Los espacios y guiones se eliminan automáticamente al enviar.');
        }
        const vence = fecha(cabecera.licencia_chofer_vencimiento);
        if (texto(cabecera.licencia_chofer_vencimiento) && !vence) {
          error('CHOFER_LICENCIA_FECHA', 'idChofer', 'La fecha de vencimiento de la licencia no es válida. Revísala en Configuración → Choferes → Licencias.');
        } else if (vence && vence < hoy) {
          error('CHOFER_LICENCIA_VENCIDA', 'idChofer', `La licencia ${licencia} del chofer venció el ${vence}`);
        }
      }
      const nombres = nombresChofer(cabecera);
      if (!nombres.nombres) {
        error('CHOFER_NOMBRES', 'idChofer', 'El chofer no tiene nombres registrados');
      } else if (!nombres.estructurado) {
        advertencia(
          'CHOFER_NOMBRES_DERIVADOS',
          'idChofer',
          'El chofer no tiene nombres y apellidos por separado; se enviarán derivados del nombre completo',
        );
      }
    }
  } else {
    const rucTrans = normalizarDocumentoSunat(cabecera.documento_transportista);
    if (!RE_RUC.test(rucTrans)) {
      error('TRANSPORTISTA_RUC', 'idTransportista', 'El transporte público requiere transportista con RUC de 11 dígitos');
    }
    if (!texto(cabecera.nombre_transportista)) {
      error('TRANSPORTISTA_NOMBRE', 'idTransportista', 'El transportista no tiene razón social');
    }
  }

  return problemas;
}

export function soloErrores(problemas: GreProblema[]): GreProblema[] {
  return problemas.filter((p) => p.severidad === 'error');
}
