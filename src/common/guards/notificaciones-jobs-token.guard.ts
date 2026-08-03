import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { timingSafeEqual } from 'crypto';
import type { Request } from 'express';

/**
 * Autenticación de jobs HTTP de notificaciones con token de entorno
 * (`NOTIFICACIONES_JOBS_TOKEN`), pensado para cron/hosting (no caduca).
 *
 * Acepta:
 * - Header `X-Notificaciones-Jobs-Token: <token>`
 * - `Authorization: Bearer <token>` (mismo valor del env)
 */
@Injectable()
export class NotificacionesJobsTokenGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const expected = process.env.NOTIFICACIONES_JOBS_TOKEN?.trim();
    if (!expected) {
      throw new UnauthorizedException(
        'NOTIFICACIONES_JOBS_TOKEN no está configurado en el servidor',
      );
    }

    const req = context.switchToHttp().getRequest<Request>();
    const provided = this.extractToken(req);
    if (!provided || !this.tokensMatch(expected, provided)) {
      throw new UnauthorizedException('Token de jobs de notificaciones inválido');
    }

    return true;
  }

  private extractToken(req: Request): string | undefined {
    const header = req.header('x-notificaciones-jobs-token')?.trim();
    if (header) {
      return header;
    }

    const auth = req.header('authorization')?.trim();
    if (auth?.toLowerCase().startsWith('bearer ')) {
      return auth.slice(7).trim() || undefined;
    }

    return undefined;
  }

  private tokensMatch(expected: string, provided: string): boolean {
    const a = Buffer.from(expected);
    const b = Buffer.from(provided);
    if (a.length !== b.length) {
      return false;
    }
    return timingSafeEqual(a, b);
  }
}
