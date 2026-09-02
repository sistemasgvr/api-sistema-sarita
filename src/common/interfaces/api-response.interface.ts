export interface ApiMeta {
  pagina: number;
  limite: number;
  total: number;
  /** Datos adicionales de reportes (p. ej. resumen de antigüedad). */
  resumen?: Record<string, unknown> | null;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  message: string;
  data: T | null;
  meta?: ApiMeta;
}

export interface ApiErrorResponse {
  success: false;
  message: string;
  data: null;
  errors: string[] | null;
  statusCode: number;
  /**
   * Datos estructurados de un error accionable, para que el frontend pueda ofrecer
   * una salida en vez de solo mostrar el mensaje. Se propaga cuando la excepción se
   * lanza con `new BadRequestException({ message, detalle: { ... } })`.
   */
  detalle?: Record<string, unknown>;
}
