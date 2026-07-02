import { Logger } from '@nestjs/common';
import { NextFunction, Request, Response } from 'express';

const logger = new Logger('HTTP');
const DEFAULT_MAX_BODY_LENGTH = 2000;
const SENSITIVE_KEYS = new Set([
  'authorization',
  'token',
  'accessToken',
  'refreshToken',
  'contrasena',
  'password',
  'clave',
  'claveSol',
  'clave_sol',
  'claveCertificado',
  'clave_certificado',
]);

interface LoggedResponseLocals {
  errorCause?: {
    message: string;
    code?: string;
    detail?: string;
    table?: string;
    constraint?: string;
  };
}

function isRequestLoggerEnabled() {
  return process.env.HTTP_REQUEST_LOGGER_ENABLED !== 'false';
}

function getMaxBodyLength() {
  const value = Number(process.env.HTTP_REQUEST_LOGGER_MAX_BODY_LENGTH);
  return Number.isFinite(value) && value >= 0 ? value : DEFAULT_MAX_BODY_LENGTH;
}

function sanitizeValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeValue(item));
  }

  if (value && typeof value === 'object') {
    const sanitized: Record<string, unknown> = {};

    for (const [key, childValue] of Object.entries(value)) {
      sanitized[key] = SENSITIVE_KEYS.has(key)
        ? '[REDACTED]'
        : sanitizeValue(childValue);
    }

    return sanitized;
  }

  return value;
}

function stringifyBody(value: unknown) {
  const maxLength = getMaxBodyLength();

  if (maxLength === 0 || value == null) {
    return undefined;
  }

  const sanitized = sanitizeValue(value);
  const text =
    typeof sanitized === 'string' ? sanitized : JSON.stringify(sanitized);

  if (text.length <= maxLength) {
    return text;
  }

  return `${text.slice(0, maxLength)}... [truncated]`;
}

function stringifyCause(cause: LoggedResponseLocals['errorCause']) {
  if (!cause) {
    return undefined;
  }

  return (
    cause.message +
    (cause.code ? ` | code=${cause.code}` : '') +
    (cause.detail ? ` | detail=${cause.detail}` : '') +
    (cause.table ? ` | table=${cause.table}` : '') +
    (cause.constraint ? ` | constraint=${cause.constraint}` : '')
  );
}

export function httpRequestLoggerMiddleware(
  request: Request,
  response: Response,
  next: NextFunction,
) {
  if (!isRequestLoggerEnabled()) {
    next();
    return;
  }

  const start = Date.now();
  const { method, originalUrl } = request;
  const ip = request.ip ?? request.socket.remoteAddress ?? '-';
  const originalJson = response.json.bind(response);
  const originalSend = response.send.bind(response);
  let responseBody: unknown;

  response.json = ((body: unknown) => {
    responseBody = body;
    return originalJson(body);
  }) as Response['json'];

  response.send = ((body: unknown) => {
    responseBody = body;
    return originalSend(body);
  }) as Response['send'];

  response.on('finish', () => {
    const durationMs = Date.now() - start;
    const { statusCode } = response;
    const contentLength = response.getHeader('content-length') ?? '-';
    const responseText = stringifyBody(responseBody);
    const causeText = stringifyCause(
      (response.locals as LoggedResponseLocals).errorCause,
    );
    const baseMessage = `${method} ${originalUrl} ${statusCode} ${durationMs}ms ${contentLength}b ip=${ip}`;
    const responseMessage = responseText
      ? `${baseMessage} response=${responseText}`
      : baseMessage;
    const message = causeText
      ? `${responseMessage} cause=${causeText}`
      : responseMessage;

    if (statusCode >= 500) {
      logger.error(message);
      return;
    }

    if (statusCode >= 400) {
      logger.warn(message);
      return;
    }

    logger.log(message);
  });

  next();
}
