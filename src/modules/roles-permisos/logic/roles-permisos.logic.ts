import { ForbiddenException, Injectable } from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { AsignarRolPermisoDto } from '../dto/asignar-rol-permiso.dto';
import { FiltroRolesPermisosDto } from '../dto/roles-permisos.dto';
import { RolesPermisosModel } from '../models/roles-permisos.model';

@Injectable()
export class RolesPermisosLogic {
  constructor(private readonly rolesPermisosModel: RolesPermisosModel) {}

  async listar(filtros: FiltroRolesPermisosDto) {
    const result = await this.rolesPermisosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async asignar(dto: AsignarRolPermisoDto, permisosCaller: string[] = []) {
    const callerTieneTodo = permisosCaller.includes(PermisoBanderas.AUTH_TODO);
    if (!callerTieneTodo) {
      const esAuthTodo = await this.rolesPermisosModel.esPermisoAuthTodo(
        dto.idPermiso,
      );
      if (esAuthTodo) {
        throw new ForbiddenException(
          'Solo un usuario con auth.todo puede asignar el permiso auth.todo',
        );
      }
    }

    const result = await this.rolesPermisosModel.asignar(
      dto.idRol,
      dto.idPermiso,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo asignar el permiso al rol');
  }

  async quitar(
    id: number,
    idUsuarioAuditoria?: number,
    permisosCaller: string[] = [],
  ) {
    const callerTieneTodo = permisosCaller.includes(PermisoBanderas.AUTH_TODO);
    if (!callerTieneTodo) {
      const idPermiso =
        await this.rolesPermisosModel.obtenerIdPermisoDeAsignacion(id);
      if (idPermiso != null) {
        const esAuthTodo =
          await this.rolesPermisosModel.esPermisoAuthTodo(idPermiso);
        if (esAuthTodo) {
          throw new ForbiddenException(
            'Solo un usuario con auth.todo puede quitar el permiso auth.todo',
          );
        }
      }
    }

    const result = await this.rolesPermisosModel.quitar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Asignación ${id} no encontrada`);
  }
}
