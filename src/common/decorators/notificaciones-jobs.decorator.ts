import { applyDecorators, UseGuards } from '@nestjs/common';
import { ApiHeader } from '@nestjs/swagger';
import { NotificacionesJobsTokenGuard } from '../guards/notificaciones-jobs-token.guard';
import { Public } from './public.decorator';

/** Auth de jobs HTTP con `NOTIFICACIONES_JOBS_TOKEN` (sin JWT). */
export function NotificacionesJobsAuth() {
  return applyDecorators(
    Public(),
    UseGuards(NotificacionesJobsTokenGuard),
    ApiHeader({
      name: 'X-Notificaciones-Jobs-Token',
      description:
        'Token de entorno NOTIFICACIONES_JOBS_TOKEN (también acepta Authorization: Bearer <token>)',
      required: true,
    }),
  );
}
