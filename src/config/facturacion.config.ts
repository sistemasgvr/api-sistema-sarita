import { registerAs } from '@nestjs/config';

/**
 * APIsPERU — Facturación electrónica
 * Swagger: https://facturacion.apisperu.com/doc
 * Base URL: https://facturacion.apisperu.com/api/v1
 */
export default registerAs('facturacion', () => ({
  enabled: process.env.FACTURACION_APISPERU_ENABLED !== 'false',
  baseUrl:
    process.env.FACTURACION_APISPERU_BASE_URL ??
    'https://facturacion.apisperu.com/api/v1',
  /** Token Bearer de empresa (no caduca) o JWT de sesión (24h). */
  token: process.env.FACTURACION_APISPERU_TOKEN ?? '',
  username: process.env.FACTURACION_APISPERU_USERNAME ?? '',
  password: process.env.FACTURACION_APISPERU_PASSWORD ?? '',
  /** RUC emisor por defecto (consultas multi-empresa). */
  defaultRuc: process.env.FACTURACION_APISPERU_RUC ?? '',
  timeoutMs: Number(process.env.FACTURACION_APISPERU_TIMEOUT_MS ?? 60_000),
}));
