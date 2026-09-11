import { ForbiddenException, Injectable } from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { AsignarUsuarioRolDto } from '../dto/asignar-usuario-rol.dto';
import { FiltroUsuariosRolesDto } from '../dto/usuarios-roles.dto';
import { UsuariosRolesModel } from '../models/usuarios-roles.model';

@Injectable()
export class UsuariosRolesLogic {
  constructor(private readonly usuariosRolesModel: UsuariosRolesModel) {}

  async listar(filtros: FiltroUsuariosRolesDto) {
    const result = await this.usuariosRolesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async asignar(dto: AsignarUsuarioRolDto, permisosCaller: string[] = []) {
    const callerTieneTodo = permisosCaller.includes(PermisoBanderas.AUTH_TODO);
    if (!callerTieneTodo) {
      const privilegiado = await this.usuariosRolesModel.esRolPrivilegiado(
        dto.idRol,
      );
      if (privilegiado) {
        throw new ForbiddenException(
          'Solo un usuario con auth.todo puede asignar el rol Administrador o roles con auth.todo',
        );
      }
    }

    const result = await this.usuariosRolesModel.asignar(
      dto.idUsuario,
      dto.idRol,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo asignar el rol al usuario');
  }

  async quitar(
    id: number,
    idUsuarioAuditoria?: number,
    permisosCaller: string[] = [],
  ) {
    const callerTieneTodo = permisosCaller.includes(PermisoBanderas.AUTH_TODO);
    if (!callerTieneTodo) {
      const idRol = await this.usuariosRolesModel.obtenerIdRolDeAsignacion(id);
      if (idRol != null) {
        const privilegiado =
          await this.usuariosRolesModel.esRolPrivilegiado(idRol);
        if (privilegiado) {
          throw new ForbiddenException(
            'Solo un usuario con auth.todo puede quitar el rol Administrador o roles con auth.todo',
          );
        }
      }
    }

    const result = await this.usuariosRolesModel.quitar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Asignación ${id} no encontrada`);
  }
}
