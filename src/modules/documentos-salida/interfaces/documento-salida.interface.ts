/** Fila de `doc_salida_detalle` — o de `ven_comprobante_detalle` cuando el
 * documento viene de una venta (`origen_detalle: 'VENTA'`), tal como lo
 * arma `doc_obtener_salida`. */
export interface DocumentoSalidaDetalleRegistro {
  id: number;
  item: number;
  id_producto: number | null;
  codigo_producto: string | null;
  descripcion: string | null;
  id_balon: number | null;
  codigo_balon: string | null;
  cantidad: number;
  id_unidad_medida: number | null;
  nombre_unidad_medida: string | null;
  codigo_unidad_medida: string | null;
  nombre_producto: string | null;
  glosa: string | null;
  id_movimiento: number | null;
  origen_detalle: 'VENTA' | 'PROPIO';
}

export interface DocumentoSalidaReferenciaRegistro {
  id: number;
  id_tipo_comprobante: number | null;
  nombre_tipo_comprobante: string | null;
  codigo_tipo_comprobante: string | null;
  id_comprobante: number | null;
  serie: string | null;
  numero: string | null;
  fecha: string | null;
}

/** Cabecera completa devuelta por `doc_obtener_salida`. */
export interface DocumentoSalidaRegistro {
  id: number;
  numero: string;
  id_tipo_orden: number;
  nombre_tipo_orden: string;
  id_estado_ciclo: number;
  nombre_estado_ciclo: 'BORRADOR' | 'GENERADA' | 'EMITIDA_SUNAT' | 'ANULADA';
  emitido_sunat: boolean;
  id_venta: number | null;
  serie_venta: string | null;
  numero_venta: string | null;
  id_doc_salida_origen: number | null;
  id_sucursal: number;
  nombre_sucursal: string | null;
  id_almacen: number;
  nombre_almacen: string | null;
  id_cliente: number | null;
  nombre_cliente: string | null;
  id_destinatario: number | null;
  destinatario_nombre: string | null;
  destinatario_documento: string | null;
  nombre_destinatario: string | null;
  documento_destinatario: string | null;
  nombre_tipo_doc_destinatario: string | null;
  documento_cliente: string | null;
  nombre_tipo_doc_cliente: string | null;
  id_proveedor: number | null;
  nombre_proveedor: string | null;
  fecha: string;
  fecha_traslado: string | null;
  fecha_retorno: string | null;
  id_tipo_guia_remision: number | null;
  nombre_tipo_guia_remision: string | null;
  codigo_tipo_guia: string | null;
  serie: string | null;
  numero_sunat: string | null;
  id_estado_sunat: number | null;
  nombre_estado_sunat: string | null;
  ticket_sunat: string | null;
  hash_documento: string | null;
  cdr_respuesta: string | null;
  tipo_cambio: number | null;
  id_motivo_traslado: number | null;
  nombre_motivo_traslado: string | null;
  codigo_motivo_traslado: string | null;
  id_modalidad_traslado: number | null;
  nombre_modalidad_traslado: string | null;
  codigo_modalidad_traslado: string | null;
  id_unidad_medida: number | null;
  nombre_unidad_medida: string | null;
  codigo_unidad_medida: string | null;
  peso_bruto: number | null;
  numero_bultos: number | null;
  direccion_origen: string | null;
  id_distrito_origen: number | null;
  ubigeo_origen: string | null;
  direccion_llegada: string | null;
  id_distrito_llegada: number | null;
  ubigeo_llegada: string | null;
  direccion_entrega: string | null;
  referencia_entrega: string | null;
  latitud: number | null;
  longitud: number | null;
  id_distrito_entrega: number | null;
  nombre_distrito_entrega: string | null;
  ubigeo_entrega: string | null;
  id_direccion_cliente: number | null;
  id_transportista: number | null;
  nombre_transportista: string | null;
  documento_transportista: string | null;
  id_chofer: number | null;
  nombre_chofer: string | null;
  documento_chofer: string | null;
  codigo_tipo_doc_chofer: string | null;
  licencia_chofer: string | null;
  id_vehiculo: number | null;
  placa_vehiculo: string | null;
  placa: string | null;
  id_responsable: number | null;
  remitente_nombre: string | null;
  remitente_documento: string | null;
  id_comprobante_compra: number | null;
  serie_guia_salida: string | null;
  numero_guia_salida: string | null;
  serie_guia_ingreso: string | null;
  numero_guia_ingreso: string | null;
  serie_factura: string | null;
  numero_factura: string | null;
  fecha_llegada_almacen: string | null;
  lote: string | null;
  fecha_vencimiento_lote: string | null;
  fecha_prueba_hidrostatica: string | null;
  periodo_contable: string | null;
  operacion: string | null;
  observaciones: string | null;
  id_archivo_pdf: number | null;
  estado: number;
  fecha_creacion: string;
  fecha_modificacion: string | null;
  id_usuario_creacion: number | null;
  nombre_usuario_creacion: string | null;
  detalle_desde_venta: boolean;
  detalle: DocumentoSalidaDetalleRegistro[];
  referencias: DocumentoSalidaReferenciaRegistro[];
}

export interface DocumentoSalidaCompletoResult {
  registro: DocumentoSalidaRegistro | null;
  error?: string;
}

/** Fila liviana de `doc_listar_salidas`. */
export interface DocumentoSalidaListItem {
  id: number;
  numero: string;
  id_tipo_orden: number;
  nombre_tipo_orden: string;
  id_estado_ciclo: number;
  nombre_estado_ciclo: string;
  emitido_sunat: boolean;
  serie: string | null;
  numero_sunat: string | null;
  id_estado_sunat: number | null;
  nombre_estado_sunat: string | null;
  id_venta: number | null;
  serie_venta: string | null;
  numero_venta: string | null;
  fecha: string;
  fecha_traslado: string | null;
  fecha_llegada_almacen: string | null;
  id_sucursal: number;
  nombre_sucursal: string | null;
  id_almacen: number;
  nombre_almacen: string | null;
  id_cliente: number | null;
  nombre_cliente: string | null;
  id_proveedor: number | null;
  nombre_proveedor: string | null;
  id_comprobante_compra: number | null;
  lote: string | null;
  observaciones: string | null;
  detalle_desde_venta: boolean;
  total_items: number;
  fecha_creacion: string;
}

export interface DocumentoSalidaListResumen {
  total: number;
  borrador: number;
  generada: number;
  emitida_sunat: number;
  anulada: number;
  [key: string]: unknown;
}

export interface DocumentoSalidaListResult {
  registros: DocumentoSalidaListItem[];
  total: number;
  resumen: DocumentoSalidaListResumen;
}

export interface ListaOpcionBasica {
  id: number;
  nombre: string;
  descripcion: string | null;
}

export interface DocumentoSalidaCatalogos {
  tiposOrden: ListaOpcionBasica[];
  estadosCiclo: ListaOpcionBasica[];
  tiposGuia: ListaOpcionBasica[];
  modalidadesTraslado: ListaOpcionBasica[];
  motivosTraslado: ListaOpcionBasica[];
  estadosSunat: ListaOpcionBasica[];
  unidadesMedida: ListaOpcionBasica[];
}

export interface DocSalidaEliminarDetalleResult {
  eliminado: boolean;
  id: number;
  error?: string;
}
