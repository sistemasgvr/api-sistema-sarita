import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { AuthCloseResult } from '../../../common/interfaces/auth-db.interface';
import { LoginDto } from '../dto/login.dto';
import { LoginModel } from '../models/login.model';

@Injectable()
export class LoginLogic {
  constructor(
    private readonly loginModel: LoginModel,
    private readonly jwtService: JwtService,
  ) {}

  async login(dto: LoginDto) {
    const result = await this.loginModel.obtenerUsuarioPorCorreo(dto.correo);
    const usuario = result.registro;

    if (!usuario) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const passwordValida = await bcrypt.compare(dto.contrasena, usuario.contrasena);

    if (!passwordValida) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const token = await this.jwtService.signAsync({
      sub: usuario.id,
      correo: usuario.correo,
      jti: randomUUID(),
    });

    await this.loginModel.crearSesion(
      usuario.id,
      token,
      dto.ip ?? null,
      dto.userAgent ?? null,
    );

    const permisosResult = await this.loginModel.obtenerPermisosUsuario(
      usuario.id,
    );

    const { contrasena: _, ...usuarioSinClave } = usuario;

    return {
      token,
      usuario: {
        ...usuarioSinClave,
        permisos: permisosResult.permisos ?? [],
      },
    };
  }

  async logout(idSesion: number, idUsuario: number): Promise<AuthCloseResult> {
    const result = await this.loginModel.cerrarSesion(idSesion, idUsuario);

    if (!result.cerrada) {
      throw new UnauthorizedException('No se pudo cerrar la sesión');
    }

    return result;
  }
}
