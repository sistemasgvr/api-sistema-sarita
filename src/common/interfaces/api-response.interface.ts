export interface ApiMeta {
  pagina: number;
  limite: number;
  total: number;
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
}
