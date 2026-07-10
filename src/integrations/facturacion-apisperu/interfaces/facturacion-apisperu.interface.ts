/** Respuesta genérica de APIsPERU Facturación. */
export type FacturacionApisperuPayload = Record<string, unknown>;

export interface FacturacionApisperuLoginRequest {
  username: string;
  password: string;
}

export interface FacturacionApisperuLoginResponse {
  token: string;
}

export interface FacturacionApisperuCompanyPayload extends FacturacionApisperuPayload {
  ruc: string;
  razon_social: string;
  direccion: string;
  certificado: string;
  logo: string;
  sol_user: string;
  sol_pass: string;
  plan: 'free' | 'premium' | string;
  environment:
    | 'beta'
    | 'produccion'
    | 'nubefact_beta'
    | 'nubefact_produccion'
    | string;
  client_id?: string;
  client_secret?: string;
}

export interface FacturacionApisperuDocumentResponse {
  xml?: string;
  hash?: string;
  sunatResponse?: FacturacionApisperuPayload;
}

export interface FacturacionApisperuValidationError {
  message?: string;
  field?: string;
}

export interface FacturacionComprobanteStatusQuery {
  tipo: string;
  serie: string;
  numero: string;
  ruc?: string;
}

export interface FacturacionResumenStatusQuery {
  ticket: string;
  ruc?: string;
}

export interface FacturacionConfigStatus {
  enabled: boolean;
  configured: boolean;
  baseUrl: string;
  hasToken: boolean;
  hasCredentials: boolean;
  defaultRuc: string | null;
}
