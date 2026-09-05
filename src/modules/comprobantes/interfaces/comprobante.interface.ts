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
  codigo_tipo_comprobante_origen?: string | null;
  nombre_tipo_comprobante_origen?: string | null;
  id_motivo_nota?: number | null;
  codigo_motivo_nota?: string | null;
  nombre_motivo_nota?: string | null;
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
  origen_pos?: string | null;
  id_estado?: number | null;
  nombre_estado?: string | null;
  ticket_sunat?: string | null;
  hash_documento?: string | null;
  xml_firmado?: string | null;
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
  id_balon?: number | null;
  codigo_balon?: string | null;
  /**
   * Línea de garantía cobrada dentro de la venta. El POS ya no las crea: la
   * garantía vive en ven_garantia y llega por `garantias`. La bandera existe
   * para los comprobantes emitidos antes de ese cambio, que sí las tienen
   * guardadas — sirve para mostrarlas como garantía y para excluirlas del
   * envío a SUNAT, que solo lleva la venta real.
   */
  es_linea_garantia?: boolean | null;
}

export interface ComprobanteBalonPrestamoRegistro {
  id: number;
  /** ENTREGADO = se lo lleva el cliente; GARANTIA = lo deja como colateral. */
  rol: string;
  id_balon?: number | null;
  codigo_balon?: string | null;
  numero_serie?: string | null;
  id_tipo_balon?: number | null;
  nombre_tipo_balon?: string | null;
  capacidad?: number | null;
  id_estado_balon?: number | null;
  nombre_estado_balon?: string | null;
  id_producto?: number | null;
  nombre_producto?: string | null;
  fecha_entregado?: string | null;
  fecha_prestamo?: string | null;
  fecha_vencimiento?: string | null;
  fecha_devolucion?: string | null;
  id_estado?: number | null;
  nombre_estado?: string | null;
  motivo_especifico?: string | null;
  observacion?: string | null;
}

export interface ComprobantePrestamoRegistro {
  id: number;
  numero_prestamo?: string | null;
  id_tipo_prestamo?: number | null;
  nombre_tipo_prestamo?: string | null;
  id_almacen?: number | null;
  nombre_almacen?: string | null;
  fecha_salida?: string | null;
  fecha_retorno_pactada?: string | null;
  fecha_retorno_real?: string | null;
  titulo?: string | null;
  observacion?: string | null;
  id_estado?: number | null;
  nombre_estado?: string | null;
  id_prestamo_origen?: number | null;
  numero_prestamo_origen?: string | null;
  balones: ComprobanteBalonPrestamoRegistro[];
}

export interface ComprobanteGarantiaRegistro {
  id: number;
  id_cliente: number;
  id_prestamo?: number | null;
  numero_prestamo?: string | null;
  id_alquiler?: number | null;
  numero_alquiler?: string | null;
  id_producto?: number | null;
  nombre_producto?: string | null;
  cantidad_venta?: number | null;
  id_unidad_medida?: number | null;
  nombre_unidad_medida?: string | null;
  ubicacion?: string | null;
  fecha_registro?: string | null;
  monto_cobrado?: number | null;
  monto_devuelto?: number | null;
  monto_saldo?: number | null;
  id_estado?: number | null;
  nombre_estado?: string | null;
  id_medio_pago?: number | null;
  nombre_medio_pago?: string | null;
  observacion?: string | null;
  /** Lo cobrado por esta garantía en ESTE comprobante (lo que va al ticket). */
  monto_cobrado_comprobante?: number | null;
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
  pagos?: unknown[];
  /** Préstamos de cilindro nacidos de esta venta, con sus balones (JOIN). */
  prestamos?: ComprobantePrestamoRegistro[];
  /** Garantías cobradas junto a esta venta (JOIN). No son líneas vendibles. */
  garantias?: ComprobanteGarantiaRegistro[];
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
  motivosNotaCredito: ListaOpcionBasica[];
}

export interface ComprobanteResumenDiarioItem {
  id: number;
  codigo_tipo_comprobante?: string | null;
  nombre_tipo_comprobante?: string | null;
  serie: string;
  numero: string;
  fecha: string;
  id_cliente: number;
  nombre_cliente?: string | null;
  documento_cliente?: string | null;
  nombre_tipo_documento_cliente?: string | null;
  nombre_estado_sunat?: string | null;
  codigo_moneda?: string | null;
  valor_venta?: number | null;
  igv?: number | null;
  exonerado?: number | null;
  total_importe?: number | null;
  codigo_tipo_comprobante_origen?: string | null;
  serie_comprobante_origen?: string | null;
  numero_comprobante_origen?: string | null;
}

export interface ResumenDiarioRegistro {
  id: number;
  fecha: string;
  correlativo: string;
  identificador?: string | null;
  ticket_sunat?: string | null;
  id_estado_sunat?: number | null;
  nombre_estado_sunat?: string | null;
  hash_documento?: string | null;
  cdr_respuesta?: string | null;
  moneda?: string | null;
  cantidad_docs: number;
  total_importe: number;
  total_igv: number;
  total_valor_venta: number;
  observacion?: string | null;
  fecha_creacion?: string | null;
  nombre_usuario_creacion?: string | null;
  error?: string;
}

export interface ResumenDiarioDetalleRegistro {
  id: number;
  id_resumen: number;
  id_comprobante: number;
  item: number;
  serie?: string | null;
  numero?: string | null;
  codigo_tipo_comprobante?: string | null;
  nombre_tipo_comprobante?: string | null;
  fecha_comprobante?: string | null;
  total_importe?: number | null;
  igv?: number | null;
  valor_venta?: number | null;
  nombre_estado_sunat?: string | null;
  nombre_cliente?: string | null;
  documento_cliente?: string | null;
}

export interface ResumenDiarioCompletoResult {
  registro: ResumenDiarioRegistro | null;
  detalles?: ResumenDiarioDetalleRegistro[];
  error?: string;
}

export interface SiguienteCorrelativoResumenResult {
  fecha: string;
  ultimo_correlativo: string | null;
  correlativo: string;
}
