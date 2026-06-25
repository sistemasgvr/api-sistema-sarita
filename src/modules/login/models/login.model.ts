import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';

@Injectable()
export class LoginModel {
  constructor(private readonly db: DatabaseService) {}

  obtenerUsuarioPorCorreo(correo: string) {
    return this.db.callFunctionJson<AuthSingleResult<{
      id: number;
      nombre: string;
      correo: string;
      contrasena: string;
      estado: boolean;
      roles: unknown[];
    }>>('auth_obtener_usuario_por_correo', [correo]);
  }

  crearSesion(
    idUsuario: number,
    token: string,
    ip: string | null,
    userAgent: string | null,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_crear_sesion', [
      idUsuario,
      token,
      ip,
      userAgent,
      idUsuario,
    ]);
  }

  cerrarSesion(idSesion: number, idUsuario: number) {
    return this.db.callFunctionJson<{ cerrada: boolean; id: number }>(
      'auth_cerrar_sesion',
      [idSesion, idUsuario],
    );
  }
}
