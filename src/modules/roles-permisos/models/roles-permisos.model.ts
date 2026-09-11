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

  async obtenerIdPermisoDeAsignacion(
    idAsignacion: number,
  ): Promise<number | null> {
    const result = await this.db.query<{ id_permiso: number }>(
      `
      SELECT id_permiso
      FROM auth_roles_permisos
      WHERE id = $1 AND estado = TRUE
      `,
      [idAsignacion],
    );
    return result.rows[0]?.id_permiso ?? null;
  }

  async esPermisoAuthTodo(idPermiso: number): Promise<boolean> {
    const result = await this.db.query<{ es_auth_todo: boolean }>(
      `
      SELECT EXISTS (
        SELECT 1
        FROM auth_permisos p
        WHERE p.id = $1
          AND p.estado = TRUE
          AND p.nombre = 'auth.todo'
      ) AS es_auth_todo
      `,
      [idPermiso],
    );
    return Boolean(result.rows[0]?.es_auth_todo);
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
