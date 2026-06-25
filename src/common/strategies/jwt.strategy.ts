import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { Request } from 'express';
import { Strategy } from 'passport-jwt';
import { DatabaseService } from '../../database/database.service';
import { AuthSessionValidateResult } from '../interfaces/auth-db.interface';

export interface JwtPayload {
  sub: number;
  correo: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    configService: ConfigService,
    private readonly db: DatabaseService,
  ) {
    super({
      jwtFromRequest: (req: Request) => {
        const authHeader = req.headers.authorization ?? '';
        return authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;
      },
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('jwt.secret'),
      passReqToCallback: true,
    });
  }

  async validate(req: Request, payload: JwtPayload) {
    const authHeader = req.headers.authorization ?? '';
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.slice(7)
      : authHeader;

    const result = await this.db.callFunctionJson<AuthSessionValidateResult>(
      'auth_validar_sesion',
      [token],
    );

    if (!result.valida || !result.registro) {
      throw new UnauthorizedException('Sesión inválida o expirada');
    }

    return {
      id: payload.sub,
      correo: payload.correo,
      sesion: result.registro,
    };
  }
}
