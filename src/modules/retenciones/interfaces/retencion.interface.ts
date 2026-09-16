export interface RetencionRegistro {
  id: number;
  serie: string;
  numero: string;
  fecha_emision: string;
  id_empresa: number;
  id_proveedor: number;
  id_sucursal: number | null;
  regimen: string;
  tasa: number;
  base_imponible: number;
  monto_retenido: number;
  monto_pagado: number;
  observacion: string | null;
  id_estado_sunat: number | null;
  nombre_estado_sunat?: string | null;
  nombre_proveedor?: string | null;
  documento_proveedor?: string | null;
  tipo_documento_proveedor?: string | null;
  ticket_sunat: string | null;
  hash_documento: string | null;
  xml_firmado: string | null;
  cdr_respuesta: string | null;
  estado: number;
  fecha_creacion: string;
  fecha_modificacion: string | null;
}

export interface RetencionDetalleRegistro {
  id: number;
  id_retencion: number;
  id_compra: number | null;
  tipo_doc: string;
  num_doc: string;
  fecha_emision: string;
  fecha_retencion: string;
  moneda: string;
  imp_total: number;
  imp_retenido: number;
  imp_pagar: number;
  tipo_cambio_moneda_ref: string;
  tipo_cambio_moneda_obj: string;
  tipo_cambio_factor: number;
  tipo_cambio_fecha: string | null;
  estado: number;
}

export interface RetencionCompletoResult {
  registro: (RetencionRegistro & { detalles: RetencionDetalleRegistro[] }) | null;
  error?: string;
}

export interface RetencionListItem {
  id: number;
  serie: string;
  numero: string;
  fecha_emision: string;
  id_empresa: number;
  id_proveedor: number;
  regimen: string;
  tasa: number;
  base_imponible: number;
  monto_retenido: number;
  monto_pagado: number;
  id_estado_sunat: number | null;
  ticket_sunat: string | null;
}

export interface RetencionListResult {
  registros: RetencionListItem[];
  total: number;
  pagina: number;
  tamano: number;
}

export interface RetencionCatalogos {
  regimenesRetencion: ListaOpcionBasica[];
  estadosSunat: ListaOpcionBasica[];
}

export interface ListaOpcionBasica {
  id: number;
  codigo: string | null;
  nombre: string;
  descripcion: string | null;
}
