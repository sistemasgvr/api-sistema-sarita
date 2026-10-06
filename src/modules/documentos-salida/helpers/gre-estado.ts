export type GreEstado = 'ACEPTADO' | 'RECHAZADO' | 'PENDIENTE';

function object(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' ? value as Record<string, unknown> : {};
}
function code(value: unknown): string | undefined {
  return typeof value === 'number' || typeof value === 'string'
    ? String(value).trim() || undefined : undefined;
}

/** success describe el procesamiento HTTP/PSE; la aceptación requiere un CDR. */
export function resolverEstadoGre(response: unknown): GreEstado {
  const root = object(response);
  const result = root.sunatResponse ? object(root.sunatResponse) : root;
  const cdr = object(result.cdrResponse);
  const cdrCode = code(cdr.code);
  const statusCode = code(result.code);
  // Estado del ticket todavía en proceso, incluso si success es true.
  if (statusCode === '98') return 'PENDIENTE';
  if (cdrCode === '0' && cdr.accepted !== false) return 'ACEPTADO';
  if (cdr.accepted === true && cdrCode === undefined) return 'ACEPTADO';
  if (cdr.accepted === false || (cdrCode && /^[2-3]\d{3}$/.test(cdrCode))) return 'RECHAZADO';
  // Solo errores de validación documentales definitivos habilitan otro envío.
  const errorCode = code(object(result.error).code);
  if ((errorCode && /^[2-3]\d{3}$/.test(errorCode)) || statusCode === '99') return 'RECHAZADO';
  // Un error técnico, respuesta vacía o código 0 sin CDR no prueban aceptación
  // ni rechazo: conservar pendiente y consultar, nunca reenviar automáticamente.
  return 'PENDIENTE';
}

/**
 * Motivo por el que SUNAT no recibió el envío, o null si pudo recibirlo.
 *
 * Solo cuenta un envío sin ticket cuyo error es una respuesta HTTP 4xx del API
 * de SUNAT (p. ej. «[401] … Unauthorized» por credenciales OAuth/SOL): SUNAT
 * contestó y rechazó la petición, así que no hay guía que consultar ni riesgo de
 * duplicarla al reenviar. Timeouts, 5xx o respuestas vacías siguen siendo
 * ambiguos y quedan PENDIENTE.
 */
export function motivoEnvioNoRecibido(response: unknown): string | null {
  const root = object(response);
  const result = root.sunatResponse ? object(root.sunatResponse) : root;
  if (code(result.ticket) || code(root.ticket)) return null;
  const mensaje = object(result.error).message;
  if (typeof mensaje !== 'string') return null;
  const http = /\[(4\d\d)\]/.exec(mensaje);
  if (!http) return null;
  const detalle = /"message"\s*:\s*"([^"]+)"/.exec(mensaje)?.[1];
  return `SUNAT no recibió la guía (HTTP ${http[1]}${detalle ? ` ${detalle}` : ''}). ` +
    (http[1] === '401' || http[1] === '403'
      ? 'Revisa el client_id/secret GRE y que el usuario SOL tenga permiso de guías; luego vuelve a emitir.'
      : 'Corrige el problema y vuelve a emitir.');
}
