import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroRolesPermisosDto } from '../dto/roles-permisos.dto';

@Injectable()
export class RolesPermisosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroRolesPermisosDto) {
    return this.db.callFunctionJson<AuthListResult>('auth_listar_roles_permisos', [
      filtros.idRol ?? null,
      filtros.idPermiso ?? null,
      filtros.limite ?? 10,
      filtros.offset,
    ]);
  }

  asignar(idRol: number, idPermiso: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_asignar_rol_permiso', [
      idRol,
      idPermiso,
      idUsuarioAuditoria ?? null,
    ]);
  }

  quitar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('auth_quitar_rol_permiso', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
