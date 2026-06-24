import {
  ApiMeta,
  ApiResponse,
} from '../interfaces/api-response.interface';

export class ResponseHelper {
  static success<T>(
    data: T,
    message = 'Operación exitosa',
    meta?: ApiMeta,
  ): ApiResponse<T> {
    return {
      success: true,
      message,
      data,
      ...(meta && { meta }),
    };
  }

  static paginated<T>(
    data: T[],
    meta: ApiMeta,
    message = 'Consulta exitosa',
  ): ApiResponse<T[]> {
    return this.success(data, message, meta);
  }
}
