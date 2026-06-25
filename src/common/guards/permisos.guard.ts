import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import {
  PermisoBanderas,
  type PermisoBandera,
} from '../constants/permiso-banderas';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { PERMISOS_KEY } from '../decorators/permisos.decorator';
import type { AuthenticatedUser } from '../interfaces/authenticated-user.interface';

@Injectable()
export class PermisosGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const required = this.reflector.getAllAndOverride<PermisoBandera[]>(
      PERMISOS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!required?.length) {
      return true;
    }

    const user = context.switchToHttp().getRequest().user as
      | AuthenticatedUser
      | undefined;

    if (!user?.permisos) {
      throw new ForbiddenException('No tiene permisos suficientes');
    }

    if (user.permisos.includes(PermisoBanderas.AUTH_TODO)) {
      return true;
    }

    const faltantes = required.filter((p) => !user.permisos.includes(p));

    if (faltantes.length > 0) {
      throw new ForbiddenException(
        `Permisos requeridos: ${required.join(', ')}`,
      );
    }

    return true;
  }
}
