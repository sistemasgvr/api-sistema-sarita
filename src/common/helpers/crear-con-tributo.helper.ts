import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { TributoOrigenDto } from '../dto/tributo-origen.dto';
import { AuthSingleResult } from '../interfaces/auth-db.interface';
import { AuthenticatedUser } from '../interfaces/authenticated-user.interface';
import { PermisoBanderas } from '../constants/permiso-banderas';

type Tipo = 'percepcion' | 'retencion';
export function autorizarTributo(user: AuthenticatedUser, tipo: Tipo) {
  const permiso = tipo === 'percepcion' ? PermisoBanderas.PERCEPCIONES_CREAR : PermisoBanderas.RETENCIONES_CREAR;
  if (!user.permisos.includes(PermisoBanderas.AUTH_TODO) && !user.permisos.includes(permiso)) {
    throw new ForbiddenException(`Se requiere el permiso ${permiso}`);
  }
}

/** Guarda origen y documento asociado en una sola transacción; nunca emite al PSE. */
export async function crearConTributo(
  db: DatabaseService, tipo: Tipo, params: unknown[], tributo?: TributoOrigenDto, usuario?: number,
): Promise<AuthSingleResult> {
  const venta = tipo === 'percepcion';
  const funcion = venta ? 'ven_crear_comprobante' : 'com_crear_compra';
  if (!tributo) return db.callFunctionJson<AuthSingleResult>(funcion, params);
  const client = await db.getClient();
  try {
    await client.query('BEGIN');
    const validacion = await client.query(
      `SELECT EXISTS(SELECT 1 FROM gen_empresa WHERE id=$1 AND estado=1) AS empresa,
       EXISTS(SELECT 1 FROM gen_lista_opciones o JOIN gen_lista l ON l.id=o.id_lista
         WHERE l.nombre=$2 AND o.descripcion=$3 AND o.estado=1) AS regimen`,
      [tributo.idEmpresa, venta ? 'RegimenPercepcion' : 'RegimenRetencion', tributo.regimen],
    );
    if (!validacion.rows[0]?.empresa || !validacion.rows[0]?.regimen) {
      throw new BadRequestException('Verifica la empresa activa y el régimen seleccionado');
    }
    if (!tributo.serie.startsWith(venta ? 'P' : 'R')) throw new BadRequestException('La serie no corresponde al tipo de documento');
    const placeholders = params.map((_, i) => `$${i + 1}`).join(',');
    const { rows } = await client.query<{ result: AuthSingleResult<{ id?: number; cabecera?: { id: number }; [key: string]: unknown }> }>(
      `SELECT ${funcion}(${placeholders}) AS result`, params,
    );
    const result = rows[0].result;
    if (result.error || !result.registro) throw new BadRequestException(result.error || 'No se pudo guardar el comprobante');
    const id = venta ? result.registro.id : result.registro.cabecera?.id;
    const origen = await client.query<{
      id: number; id_tercero: number; id_sucursal: number; serie: string; numero: string;
      fecha: string; total: string; tipo_doc: string; moneda: string;
    }>(
      `SELECT c.id, c.${venta ? 'id_cliente' : 'id_proveedor'} AS id_tercero, c.id_sucursal,
       c.serie, c.numero, c.fecha::text, c.total_importe AS total,
       TRIM(t.descripcion) AS tipo_doc, m.nombre AS moneda
       FROM ${venta ? 'ven_comprobante' : 'com_comprobante_compra'} c
       JOIN gen_lista_opciones t ON t.id=c.id_tipo_comprobante
       JOIN gen_lista_opciones m ON m.id=c.id_moneda WHERE c.id=$1`, [id],
    );
    const c = origen.rows[0];
    if (!c || !c.id_tercero || !c.serie || !c.numero || !['01', '03'].includes(c.tipo_doc)) {
      throw new BadRequestException('La percepción o retención requiere un comprobante con cliente/proveedor, tipo, serie y número');
    }
    if (c.moneda !== 'PEN') throw new BadRequestException('Esta sección admite comprobantes en PEN; otras monedas requieren tipo de cambio');
    if (tributo.fechaEmision < c.fecha) throw new BadRequestException('La fecha del documento asociado no puede preceder al comprobante de origen');
    const baseCentavos = Math.round(tributo.baseImponible * 100);
    if (baseCentavos > Math.round(Number(c.total) * 100)) throw new BadRequestException('La base no puede superar el total del comprobante');
    const monto = Math.round(baseCentavos * Math.round(tributo.tasa * 100) / 10000) / 100;
    if (monto <= 0) throw new BadRequestException('El importe calculado debe ser mayor a cero');
    const neto = Math.round(baseCentavos + (venta ? 1 : -1) * Math.round(monto * 100)) / 100;
    const detalle = {
      [venta ? 'id_comprobante' : 'id_compra']: c.id,
      tipo_doc: c.tipo_doc, num_doc: `${c.serie}-${c.numero}`, fecha_emision: c.fecha,
      [venta ? 'fecha_percepcion' : 'fecha_retencion']: tributo.fechaEmision,
      moneda: c.moneda, imp_total: Number(c.total),
      [venta ? 'imp_percibido' : 'imp_retenido']: monto,
      [venta ? 'imp_cobrar' : 'imp_pagar']: neto,
    };
    const extra = await client.query<{ result: { id?: number; serie: string; numero: string; error?: string } }>(
      `SELECT ${venta ? 'ven_crear_percepcion' : 'com_crear_retencion'}(
       $1::varchar,$2::date,$3::integer,$4::integer,$5::integer,$6::varchar,
       $7::numeric,$8::numeric,$9::numeric,$10::numeric,$11::varchar,$12::jsonb,$13::integer) AS result`,
      [tributo.serie, tributo.fechaEmision, tributo.idEmpresa, c.id_tercero, c.id_sucursal,
       tributo.regimen, tributo.tasa, tributo.baseImponible, monto, neto,
       tributo.observacion ?? null, JSON.stringify([detalle]), usuario ?? null],
    );
    if (extra.rows[0].result.error || !extra.rows[0].result.id) throw new BadRequestException(extra.rows[0].result.error || 'No se pudo guardar el documento asociado');
    result.registro[tipo] = extra.rows[0].result;
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}

/** Recupera los vínculos también al volver a abrir el comprobante. */
export async function adjuntarTributos(db: DatabaseService, tipo: Tipo, id: number, result: AuthSingleResult) {
  if (!result.registro) return result;
  const venta = tipo === 'percepcion';
  const { rows } = await db.query<{ id: number; serie: string; numero: string }>(
    `SELECT DISTINCT t.id, t.serie, t.numero
     FROM ${venta ? 'ven_percepcion' : 'com_retencion'} t
     JOIN ${venta ? 'ven_percepcion_detalle' : 'com_retencion_detalle'} d
       ON d.${venta ? 'id_percepcion' : 'id_retencion'} = t.id
     WHERE d.${venta ? 'id_comprobante' : 'id_compra'}=$1 AND t.estado=1 ORDER BY t.id`, [id],
  );
  return { ...result, registro: { ...(result.registro as object), [venta ? 'percepciones' : 'retenciones']: rows } };
}
