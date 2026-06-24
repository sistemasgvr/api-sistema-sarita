import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, map } from 'rxjs';
import { ResponseHelper } from '../helpers/response.helper';
import { ApiResponse } from '../interfaces/api-response.interface';

const MESSAGES: Record<string, string> = {
  GET: 'Consulta exitosa',
  POST: 'Registro creado',
  PATCH: 'Registro actualizado',
  PUT: 'Registro actualizado',
  DELETE: 'Registro eliminado',
};

@Injectable()
export class TransformResponseInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest<{ method: string }>();
    const message = MESSAGES[request.method] ?? 'Operación exitosa';

    return next.handle().pipe(
      map((data: unknown) => {
        if (this.isApiResponse(data)) {
          return data;
        }

        return ResponseHelper.success(data, message);
      }),
    );
  }

  private isApiResponse(data: unknown): data is ApiResponse {
    return (
      typeof data === 'object' &&
      data !== null &&
      'success' in data &&
      'message' in data &&
      'data' in data
    );
  }
}
