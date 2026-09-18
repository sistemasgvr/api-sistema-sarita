import { BadRequestException } from '@nestjs/common';
import { calcularLineaTributo, redondear2 } from './comprobante-sunat.helper';

/**
 * Armado de una percepción (sobre comprobantes de venta emitidos) o una
 * retención (sobre compras registradas) a partir de sus documentos de origen.
 * Es una función pura: recibe los orígenes ya leídos y devuelve cabecera y
 * detalle listos para la función SQL, o falla con el motivo exacto.
 */

export type TipoTributo = 'percepcion' | 'retencion';

export interface OrigenTributo {
  id: number;
  estado: number;
  serie: string | null;
  numero: string | null;
  fecha: string;
  tipo_doc: string | null;
  total: number | string;
  moneda: string | null;
  id_contraparte: number | null;
  nombre_contraparte: string | null;
  documento_contraparte: string | null;
  /** Solo ventas: estado SUNAT del comprobante emitido. */
  nombre_estado_sunat?: string | null;
  /** Ya tiene percepción/retención vigente. */
  con_tributo: boolean;
  id_sucursal?: number | null;
}

export interface SolicitudTributo {
  regimen: string;
  /** Resuelta contra el catálogo de tasas del régimen antes de llegar aquí. */
  tasa: number;
  fechaEmision: string;
  origenes: { id: number; fechaOperacion?: string }[];
}

export interface DetalleTributoCalculado {
  id_origen: number;
  tipo_doc: string;
  num_doc: string;
  fecha_emision: string;
  fecha_operacion: string;
  moneda: string;
  imp_total: number;
  imp_tributo: number;
  imp_neto: number;
}

export interface TributoCalculado {
  idContraparte: number;
  idSucursal: number | null;
  tasa: number;
  baseImponible: number;
  montoTributo: number;
  montoNeto: number;
  detalles: DetalleTributoCalculado[];
}

/**
 * Estados SUNAT del comprobante de venta sobre los que se puede armar una
 * percepción: aceptado, o todavía sin enviar (rechazado, dado de baja o "no
 * aplica" —notas de venta— quedan fuera). Debe coincidir con el filtro de
 * PercepcionesModel.SQL_ELEGIBLES.
 */
export const ESTADOS_SUNAT_PERCIBIBLES = ['ACEPTADO', 'PENDIENTE'];

const ETIQUETA: Record<TipoTributo, { doc: string; contraparte: string; tributo: string }> = {
  percepcion: { doc: 'comprobante', contraparte: 'cliente', tributo: 'percepción' },
  retencion: { doc: 'compra', contraparte: 'proveedor', tributo: 'retención' },
};

export function armarTributoDesdeOrigen(
  tipo: TipoTributo,
  solicitud: SolicitudTributo,
  origenes: OrigenTributo[],
): TributoCalculado {
  const e = ETIQUETA[tipo];
  const tasa = Number(solicitud.tasa);
  if (!(tasa > 0) || tasa > 100) {
    throw new BadRequestException(`Indica la tasa de ${e.tributo} del régimen ${solicitud.regimen}`);
  }

  const idsPedidos = solicitud.origenes.map((o) => o.id);
  if (new Set(idsPedidos).size !== idsPedidos.length) {
    throw new BadRequestException(`Hay ${e.doc}s repetidos en la selección`);
  }
  const porId = new Map(origenes.map((o) => [o.id, o]));
  const faltantes = idsPedidos.filter((id) => !porId.has(id));
  if (faltantes.length > 0) {
    throw new BadRequestException(`No se encontró el ${e.doc} ${faltantes.join(', ')}`);
  }

  const detalles: DetalleTributoCalculado[] = [];
  let idContraparte: number | null = null;
  let idSucursal: number | null = null;

  for (const pedido of solicitud.origenes) {
    const o = porId.get(pedido.id)!;
    const ref = o.serie && o.numero ? `${o.serie}-${o.numero}` : `#${o.id}`;
    if (o.estado !== 1) throw new BadRequestException(`El ${e.doc} ${ref} está anulado`);
    if (!o.serie || !o.numero) throw new BadRequestException(`El ${e.doc} ${ref} no tiene serie y número`);
    if (!['01', '03'].includes((o.tipo_doc ?? '').trim())) {
      throw new BadRequestException(`El ${e.doc} ${ref} no es factura ni boleta (tipo ${o.tipo_doc ?? '—'})`);
    }
    if ((o.moneda ?? '') !== 'PEN') {
      throw new BadRequestException(`El ${e.doc} ${ref} no está en soles; otras monedas requieren tipo de cambio`);
    }
    // Pendiente de envío vale (la percepción nace al cobrar); aceptado se exige al emitirla.
    if (tipo === 'percepcion' && !ESTADOS_SUNAT_PERCIBIBLES.includes(o.nombre_estado_sunat ?? 'PENDIENTE')) {
      throw new BadRequestException(`El comprobante ${ref} está ${o.nombre_estado_sunat} ante SUNAT: no se puede percibir sobre él`);
    }
    if (o.con_tributo) throw new BadRequestException(`El ${e.doc} ${ref} ya tiene ${e.tributo}`);
    if (!o.id_contraparte) throw new BadRequestException(`El ${e.doc} ${ref} no tiene ${e.contraparte}`);
    // «Clientes varios» (documento 00000000) no identifica a nadie ante SUNAT.
    if (!(o.documento_contraparte ?? '').trim() || /^0+$/.test((o.documento_contraparte ?? '').trim())) {
      throw new BadRequestException(`El ${e.contraparte} del ${e.doc} ${ref} no tiene número de documento`);
    }
    if (tipo === 'retencion' && !/^\d{11}$/.test((o.documento_contraparte ?? '').trim())) {
      throw new BadRequestException(`La retención exige proveedor con RUC (${e.doc} ${ref})`);
    }
    if (idContraparte == null) {
      idContraparte = o.id_contraparte;
      idSucursal = o.id_sucursal ?? null;
    } else if (idContraparte !== o.id_contraparte) {
      throw new BadRequestException(`Todos los ${e.doc}s deben ser del mismo ${e.contraparte}`);
    }
    const fechaOperacion = pedido.fechaOperacion ?? solicitud.fechaEmision;
    if (fechaOperacion < o.fecha.slice(0, 10)) {
      throw new BadRequestException(`La fecha de ${tipo === 'percepcion' ? 'cobro' : 'pago'} del ${e.doc} ${ref} no puede ser anterior a su emisión`);
    }
    if (fechaOperacion > solicitud.fechaEmision) {
      throw new BadRequestException(`La fecha de ${tipo === 'percepcion' ? 'cobro' : 'pago'} del ${e.doc} ${ref} no puede ser posterior a la emisión de la ${e.tributo}`);
    }
    const total = redondear2(Number(o.total));
    if (!(total > 0)) throw new BadRequestException(`El ${e.doc} ${ref} no tiene importe`);
    const { tributo, neto } = calcularLineaTributo(total, tasa, tipo);
    if (!(tributo > 0)) throw new BadRequestException(`La ${e.tributo} del ${e.doc} ${ref} resulta en 0.00`);
    detalles.push({
      id_origen: o.id,
      tipo_doc: (o.tipo_doc ?? '').trim(),
      num_doc: ref,
      fecha_emision: o.fecha.slice(0, 10),
      fecha_operacion: fechaOperacion,
      moneda: 'PEN',
      imp_total: total,
      imp_tributo: tributo,
      imp_neto: neto,
    });
  }

  const baseImponible = redondear2(detalles.reduce((acc, d) => acc + d.imp_total, 0));
  const montoTributo = redondear2(detalles.reduce((acc, d) => acc + d.imp_tributo, 0));
  const montoNeto = redondear2(detalles.reduce((acc, d) => acc + d.imp_neto, 0));

  return { idContraparte: idContraparte!, idSucursal, tasa, baseImponible, montoTributo, montoNeto, detalles };
}
