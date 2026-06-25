import { Injectable } from '@nestjs/common';
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

  async asignar(dto: AsignarRolPermisoDto) {
    const result = await this.rolesPermisosModel.asignar(
      dto.idRol,
      dto.idPermiso,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo asignar el permiso al rol');
  }

  async quitar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.rolesPermisosModel.quitar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Asignación ${id} no encontrada`);
  }
}
