export interface AuthListResult<T = unknown> {
  registros: T[];
  total: number;
}

export interface AuthSingleResult<T = unknown> {
  registro: T | null;
  error?: string;
}

export interface AuthDeleteResult {
  eliminado: boolean;
  id: number;
}

export interface AuthCloseResult {
  cerrada: boolean;
  id: number;
}

export interface AuthSessionValidateResult<T = unknown> {
  valida: boolean;
  registro: T | null;
}

export interface AuthExisteResult {
  existe: boolean;
}
