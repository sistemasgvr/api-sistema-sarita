export interface ComprobanteRegistro {
  id: number;
  id_tipo_comprobante: number;
  nombre_tipo_comprobante?: string | null;
  codigo_tipo_comprobante?: string | null;
  serie: string;
  numero: string;
  id_estado_sunat?: number | null;
  nombre_estado_sunat?: string | null;
  id_tipo_operacion_sunat?: number | null;
  codigo_tipo_operacion_sunat?: string | null;
  id_comprobante_origen?: number | null;
  serie_comprobante_origen?: string | null;
  numero_comprobante_origen?: string | null;
  id_motivo_nota?: number | null;
  codigo_motivo_nota?: string | null;
  fecha: string;
  fecha_vencimiento?: string | null;
  tipo_cambio?: number | null;
  id_cliente: number;
  nombre_cliente?: string | null;
  documento_cliente?: string | null;
  id_sucursal?: number | null;
  id_almacen?: number | null;
  id_condicion_pago?: number | null;
  id_moneda?: number | null;
  codigo_moneda?: string | null;
  id_medio_pago?: number | null;
  sub_total?: number | null;
  descuento?: number | null;
  valor_venta?: number | null;
  igv?: number | null;
  total_importe?: number | null;
  exonerado?: number | null;
  glosa?: string | null;
  observaciones?: string | null;
  id_estado?: number | null;
  nombre_estado?: string | null;
}

export interface ComprobanteDetalleRegistro {
  id: number;
  item: number;
  id_producto: number;
  codigo_producto?: string | null;
  nombre_producto?: string | null;
  descripcion?: string | null;
  id_unidad_medida?: number | null;
  nombre_unidad_medida?: string | null;
  cantidad: number;
  precio_unitario: number;
  descuento?: number | null;
  valor_venta: number;
  porcentaje_igv?: number | null;
  id_afectacion_igv?: number | null;
  codigo_afectacion_igv?: string | null;
  impuesto?: number | null;
  importe: number;
}

export interface ComprobanteCuotaRegistro {
  id: number;
  numero_cuota: number;
  fecha_vencimiento: string;
  monto: number;
  monto_pagado?: number | null;
}

export interface ComprobanteCompletoResult {
  registro: ComprobanteRegistro | null;
  detalles?: ComprobanteDetalleRegistro[];
  cuotas?: ComprobanteCuotaRegistro[];
  error?: string;
}

export interface ListaOpcionBasica {
  id: number;
  nombre: string;
  descripcion?: string | null;
}

export interface ComprobanteCatalogosPos {
  tiposComprobante: ListaOpcionBasica[];
  afectacionesIgv: ListaOpcionBasica[];
  monedas: ListaOpcionBasica[];
  mediosPago: ListaOpcionBasica[];
  tiposOperacionSunat: ListaOpcionBasica[];
  estadosSunat: ListaOpcionBasica[];
}
