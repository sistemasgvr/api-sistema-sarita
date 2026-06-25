import { Injectable } from '@nestjs/common';
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

  async asignar(dto: AsignarUsuarioRolDto) {
    const result = await this.usuariosRolesModel.asignar(
      dto.idUsuario,
      dto.idRol,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo asignar el rol al usuario');
  }

  async quitar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.usuariosRolesModel.quitar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Asignación ${id} no encontrada`);
  }
}
