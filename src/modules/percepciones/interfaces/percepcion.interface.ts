export interface PercepcionRegistro {
  id: number;
  serie: string;
  numero: string;
  fecha_emision: string;
  id_empresa: number;
  id_cliente: number;
  id_sucursal: number | null;
  regimen: string;
  tasa: number;
  base_imponible: number;
  monto_percibido: number;
  monto_cobrado: number;
  observacion: string | null;
  id_estado_sunat: number | null;
  nombre_estado_sunat?: string | null;
  nombre_cliente?: string | null;
  documento_cliente?: string | null;
  tipo_documento_cliente?: string | null;
  ticket_sunat: string | null;
  hash_documento: string | null;
  xml_firmado: string | null;
  cdr_respuesta: string | null;
  estado: number;
  fecha_creacion: string;
  fecha_modificacion: string | null;
}

export interface PercepcionDetalleRegistro {
  id: number;
  id_percepcion: number;
  id_comprobante: number | null;
  tipo_doc: string;
  num_doc: string;
  fecha_emision: string;
  fecha_percepcion: string;
  moneda: string;
  imp_total: number;
  imp_percibido: number;
  imp_cobrar: number;
  tipo_cambio_moneda_ref: string;
  tipo_cambio_moneda_obj: string;
  tipo_cambio_factor: number;
  tipo_cambio_fecha: string | null;
  estado: number;
}

export interface PercepcionCompletoResult {
  registro: (PercepcionRegistro & { detalles: PercepcionDetalleRegistro[] }) | null;
  error?: string;
}

export interface PercepcionListItem {
  id: number;
  serie: string;
  numero: string;
  fecha_emision: string;
  id_empresa: number;
  id_cliente: number;
  regimen: string;
  tasa: number;
  base_imponible: number;
  monto_percibido: number;
  monto_cobrado: number;
  id_estado_sunat: number | null;
  ticket_sunat: string | null;
}

export interface PercepcionListResult {
  registros: PercepcionListItem[];
  total: number;
  pagina: number;
  tamano: number;
}

export interface PercepcionCatalogos {
  regimenesPercepcion: ListaOpcionBasica[];
  estadosSunat: ListaOpcionBasica[];
}

export interface ListaOpcionBasica {
  id: number;
  codigo: string | null;
  nombre: string;
  descripcion: string | null;
}
