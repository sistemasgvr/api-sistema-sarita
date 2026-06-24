import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';
import { ApiErrorResponse } from '../interfaces/api-response.interface';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
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

    const body: ApiErrorResponse = {
      success: false,
      message,
      data: null,
      errors,
      statusCode: status,
    };

    response.status(status).json(body);
  }
}
