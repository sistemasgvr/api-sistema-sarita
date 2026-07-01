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

    if (exception instanceof HttpException) {
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
    };

    response.status(status).json(body);
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
