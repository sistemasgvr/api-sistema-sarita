import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { ApiErrorResponse } from '../interfaces/api-response.interface';

interface ErrorCause {
  message: string;
  code?: string;
  detail?: string;
  table?: string;
  constraint?: string;
}

/**
 * SQLSTATE de `RAISE EXCEPTION` sin ERRCODE explícito. Las funciones de
 * negocio lo usan para abortar una operación a mitad de una mutación (p. ej.
 * "No se puede anular: el stock ya fue consumido"): la transacción se
 * deshace y el mensaje está pensado para el usuario, así que se responde 400
 * con ese texto en vez de un 500 genérico que lo esconde.
 */
const PG_RAISE_EXCEPTION = 'P0001';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const request = ctx.getRequest<Request>();
    const response = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Error interno del servidor';
    let errors: string[] | null = null;
    let detalle: Record<string, unknown> | undefined;

    if (this.isPgRaiseException(exception)) {
      status = HttpStatus.BAD_REQUEST;
      message = exception.message;
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();

      if (typeof exceptionResponse === 'string') {
        message = exceptionResponse;
      } else if (typeof exceptionResponse === 'object') {
        const res = exceptionResponse as Record<string, unknown>;
        const rawMessage = res.message;

        if (Array.isArray(rawMessage)) {
          errors = rawMessage as string[];
          message = 'Error de validación';
        } else if (typeof rawMessage === 'string') {
          message = rawMessage;
        }

        // Errores accionables: el detalle estructurado llega al cliente para que
        // pueda ofrecer una salida (p. ej. confirmar una conversión) y no solo
        // mostrar el mensaje.
        if (res.detalle && typeof res.detalle === 'object') {
          detalle = res.detalle as Record<string, unknown>;
        }
      }
    }

    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      const cause = this.getErrorCause(exception);
      response.locals.errorCause = cause;
      this.logUnhandledException(cause, exception, request);
    }

    const body: ApiErrorResponse = {
      success: false,
      message,
      data: null,
      errors,
      statusCode: status,
      ...(detalle ? { detalle } : {}),
    };

    response.status(status).json(body);
  }

  private isPgRaiseException(
    exception: unknown,
  ): exception is Error & { code: string } {
    return (
      exception instanceof Error &&
      (exception as Error & { code?: string }).code === PG_RAISE_EXCEPTION &&
      typeof exception.message === 'string' &&
      exception.message.trim() !== ''
    );
  }

  private getErrorCause(exception: unknown): ErrorCause {
    if (exception instanceof Error) {
      const dbError = exception as Error & {
        code?: string;
        detail?: string;
        table?: string;
        constraint?: string;
      };

      return {
        message: exception.message,
        code: dbError.code,
        detail: dbError.detail,
        table: dbError.table,
        constraint: dbError.constraint,
      };
    }

    return {
      message: JSON.stringify(exception),
    };
  }

  private logUnhandledException(
    cause: ErrorCause,
    exception: unknown,
    request: Request,
  ) {
    const method = request.method;
    const url = request.originalUrl;

    if (exception instanceof Error) {
      this.logger.error(
        `${method} ${url} failed: ${cause.message}` +
          `${cause.code ? ` | code=${cause.code}` : ''}` +
          `${cause.detail ? ` | detail=${cause.detail}` : ''}` +
          `${cause.table ? ` | table=${cause.table}` : ''}` +
          `${cause.constraint ? ` | constraint=${cause.constraint}` : ''}`,
        exception.stack,
      );
      return;
    }

    this.logger.error(`${method} ${url} failed: ${cause.message}`);
  }
}
