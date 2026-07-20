export interface GuiaRemisionRegistro {
  id: number;
  id_tipo_guia_remision: number;
  nombre_tipo_guia?: string | null;
  codigo_tipo_guia?: string | null;
  serie: string;
  numero: string;
  id_estado_sunat?: number | null;
  nombre_estado_sunat?: string | null;
  ticket_sunat?: string | null;
  hash_documento?: string | null;
  fecha: string;
  tipo_cambio?: number | null;
  id_sucursal: number;
  nombre_sucursal?: string | null;
  id_almacen: number;
  nombre_almacen?: string | null;
  id_cliente?: number | null;
  nombre_cliente?: string | null;
  documento_cliente?: string | null;
  codigo_tipo_doc_cliente?: string | null;
  nombre_tipo_doc_cliente?: string | null;
  fecha_traslado: string;
  id_motivo_traslado?: number | null;
  nombre_motivo_traslado?: string | null;
  codigo_motivo_traslado?: string | null;
  id_unidad_medida?: number | null;
  nombre_unidad_medida?: string | null;
  codigo_unidad_medida?: string | null;
  peso_bruto?: number | null;
  numero_bultos?: number | null;
  direccion_origen?: string | null;
  id_distrito_origen?: number | null;
  nombre_distrito_origen?: string | null;
  ubigeo_origen?: string | null;
  id_provincia_origen?: number | null;
  id_departamento_origen?: number | null;
  id_pais_origen?: number | null;
  id_destinatario?: number | null;
  nombre_destinatario?: string | null;
  documento_destinatario?: string | null;
  codigo_tipo_doc_destinatario?: string | null;
  nombre_tipo_doc_destinatario?: string | null;
  direccion_llegada?: string | null;
  id_distrito_llegada?: number | null;
  nombre_distrito_llegada?: string | null;
  ubigeo_llegada?: string | null;
  id_provincia_llegada?: number | null;
  id_departamento_llegada?: number | null;
  id_pais_llegada?: number | null;
  id_modalidad_traslado?: number | null;
  nombre_modalidad_traslado?: string | null;
  codigo_modalidad_traslado?: string | null;
  id_transportista?: number | null;
  nombre_transportista?: string | null;
  documento_transportista?: string | null;
  id_chofer?: number | null;
  nombre_chofer?: string | null;
  documento_chofer?: string | null;
  codigo_tipo_doc_chofer?: string | null;
  licencia_chofer?: string | null;
  id_vehiculo?: number | null;
  placa_vehiculo?: string | null;
  id_responsable?: number | null;
  observaciones?: string | null;
  id_estado?: number | null;
  nombre_estado?: string | null;
  estado?: number;
  fecha_creacion?: string;
  fecha_modificacion?: string;
}

export interface GuiaRemisionDetalleRegistro {
  id: number;
  item: number;
  id_producto: number;
  codigo_producto?: string | null;
  nombre_producto?: string | null;
  descripcion?: string | null;
  id_unidad_medida?: number | null;
  nombre_unidad_medida?: string | null;
  codigo_unidad_medida?: string | null;
  cantidad: number;
  id_balon?: number | null;
  codigo_balon?: string | null;
  glosa?: string | null;
}

export interface GuiaRemisionReferenciaRegistro {
  id: number;
  id_tipo_comprobante: number;
  nombre_tipo_comprobante?: string | null;
  codigo_tipo_comprobante?: string | null;
  serie?: string | null;
  numero?: string | null;
  fecha?: string | null;
}

export interface GuiaRemisionCompletoResult {
  registro: GuiaRemisionRegistro | null;
  detalles?: GuiaRemisionDetalleRegistro[];
  referencias?: GuiaRemisionReferenciaRegistro[];
  error?: string;
}

export interface ListaOpcionBasica {
  id: number;
  nombre: string;
  descripcion?: string | null;
}

export interface GuiaRemisionCatalogos {
  tiposGuia: ListaOpcionBasica[];
  modalidadesTraslado: ListaOpcionBasica[];
  motivosTraslado: ListaOpcionBasica[];
  estadosGuia: ListaOpcionBasica[];
  estadosSunat: ListaOpcionBasica[];
  unidadesMedida: ListaOpcionBasica[];
}

export interface SiguienteNumeroGuiaResult {
  serie: string;
  numero: string;
  error?: string;
}
