import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreatePermisoDto, UpdatePermisoDto } from '../dto/permisos.dto';
import { PermisosModel } from '../models/permisos.model';

@Injectable()
export class PermisosLogic {
  constructor(private readonly permisosModel: PermisosModel) {}

  async listar(filtros: FiltroPaginacionDto) {
    const result = await this.permisosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.permisosModel.obtenerPorId(id);
    return mapSingleResult(result, `Permiso ${id} no encontrado`);
  }

  async crear(dto: CreatePermisoDto) {
    const result = await this.permisosModel.crear(
      dto.nombre,
      dto.descripcion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear el permiso');
  }

  async actualizar(id: number, dto: UpdatePermisoDto) {
    const result = await this.permisosModel.actualizar(
      id,
      dto.nombre ?? null,
      dto.descripcion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Permiso ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.permisosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Permiso ${id} no encontrado`);
  }
}
