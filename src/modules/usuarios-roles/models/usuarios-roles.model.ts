import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroUsuariosRolesDto } from '../dto/usuarios-roles.dto';

@Injectable()
export class UsuariosRolesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroUsuariosRolesDto) {
    return this.db.callFunctionJson<AuthListResult>('auth_listar_usuarios_roles', [
      filtros.idUsuario ?? null,
      filtros.idRol ?? null,
      filtros.limite ?? 10,
      filtros.offset,
    ]);
  }

  asignar(idUsuario: number, idRol: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_asignar_usuario_rol', [
      idUsuario,
      idRol,
      idUsuarioAuditoria ?? null,
    ]);
  }

  quitar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('auth_quitar_usuario_rol', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
