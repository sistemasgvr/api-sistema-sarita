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
