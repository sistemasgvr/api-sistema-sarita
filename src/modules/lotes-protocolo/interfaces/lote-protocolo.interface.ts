/** Fila de "DATOS DE ANÁLISIS" de la ficha ICP. */
export interface LoteProtocoloPrueba {
  id: number;
  orden: number;
  prueba: string;
  especificacion: string | null;
  resultado: string | null;
}

/** Fila de "RELACIÓN DE ENVASES APROBADOS". */
export interface LoteProtocoloEnvase {
  id: number;
  serie_envase: string;
  /** NULL cuando la planta incluyó un envase que no está registrado aquí. */
  id_balon: number | null;
  codigo_balon: string | null;
  nombre_tipo_balon: string | null;
  nombre_estado_balon: string | null;
  es_lote_vigente: boolean | null;
}

export interface LoteProtocolo {
  id: number;
  numero_lote: string;
  numero_protocolo: string | null;
  id_proveedor: number | null;
  nombre_proveedor: string | null;
  id_producto_gas: number | null;
  nombre_producto_gas: string | null;
  fecha_vencimiento: string | null;
  vencido: boolean;
  id_archivo_pdf: number | null;
  ruta_archivo_pdf: string | null;
  pruebas?: LoteProtocoloPrueba[];
  envases?: LoteProtocoloEnvase[];
  [key: string]: unknown;
}

/** Una recarga del cilindro que referencia una ficha. */
export interface LoteProtocoloHistorialItem {
  origen: 'PLANTA_EXTERNA' | 'MOVIMIENTO_RECARGA';
  id_documento: number;
  numero_documento: string | null;
  fecha: string | null;
  id_lote_protocolo: number;
  numero_lote: string;
  numero_protocolo: string | null;
  fecha_vencimiento: string | null;
  vencido: boolean;
  es_vigente: boolean;
  [key: string]: unknown;
}

export interface LoteProtocoloHistorialResult {
  error: string | null;
  registros: LoteProtocoloHistorialItem[];
  total: number;
  vigente: LoteProtocolo | null;
}

export interface AplicarLoteProtocoloResult {
  error: string | null;
  registro: {
    id_lote_protocolo: number;
    balones_aplicados: number;
    envases_vinculados: number;
  } | null;
}
