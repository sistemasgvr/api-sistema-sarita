import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthCloseResult,
  AuthListResult,
  AuthSessionValidateResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroSesionesDto } from '../dto/sesiones.dto';

@Injectable()
export class SesionesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroSesionesDto) {
    return this.db.callFunctionJson<AuthListResult>('auth_listar_sesiones', [
      filtros.idUsuario ?? null,
      filtros.soloActivas ?? true,
      filtros.limite ?? 10,
      filtros.offset,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_obtener_sesion', [id]);
  }

  crear(
    idUsuario: number,
    token: string,
    ip: string | null,
    userAgent: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_crear_sesion', [
      idUsuario,
      token,
      ip,
      userAgent,
      idUsuarioAuditoria ?? null,
    ]);
  }

  cerrar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthCloseResult>('auth_cerrar_sesion', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  validar(token: string) {
    return this.db.callFunctionJson<AuthSessionValidateResult>(
      'auth_validar_sesion',
      [token],
    );
  }
}
