import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateRolDto, UpdateRolDto } from '../dto/roles.dto';
import { RolesModel } from '../models/roles.model';

@Injectable()
export class RolesLogic {
  constructor(private readonly rolesModel: RolesModel) {}

  async listar(filtros: FiltroPaginacionDto) {
    const result = await this.rolesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.rolesModel.obtenerPorId(id);
    return mapSingleResult(result, `Rol ${id} no encontrado`);
  }

  async crear(dto: CreateRolDto) {
    const result = await this.rolesModel.crear(
      dto.nombre,
      dto.descripcion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear el rol');
  }

  async actualizar(id: number, dto: UpdateRolDto) {
    const result = await this.rolesModel.actualizar(
      id,
      dto.nombre ?? null,
      dto.descripcion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Rol ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.rolesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Rol ${id} no encontrado`);
  }
}
