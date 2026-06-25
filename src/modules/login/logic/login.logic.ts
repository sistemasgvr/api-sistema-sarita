import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
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

    const { contrasena: _, ...usuarioSinClave } = usuario;

    return {
      token,
      usuario: usuarioSinClave,
    };
  }

  async logout(idSesion: number, idUsuario: number) {
    const result = await this.loginModel.cerrarSesion(idSesion, idUsuario);

    if (!result.cerrada) {
      throw new UnauthorizedException('No se pudo cerrar la sesión');
    }

    return result;
  }
}
