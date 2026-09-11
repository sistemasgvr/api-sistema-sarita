import { ForbiddenException, Injectable } from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
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

  async actualizar(
    id: number,
    dto: UpdateRolDto,
    permisosCaller: string[] = [],
  ) {
    await this.assertPuedeMutarPrivilegiado(id, permisosCaller, 'actualizar');
    const result = await this.rolesModel.actualizar(
      id,
      dto.nombre ?? null,
      dto.descripcion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Rol ${id} no encontrado`);
  }

  async eliminar(
    id: number,
    idUsuarioAuditoria?: number,
    permisosCaller: string[] = [],
  ) {
    await this.assertPuedeMutarPrivilegiado(id, permisosCaller, 'eliminar');
    const result = await this.rolesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Rol ${id} no encontrado`);
  }

  private async assertPuedeMutarPrivilegiado(
    id: number,
    permisosCaller: string[],
    accion: 'actualizar' | 'eliminar',
  ) {
    if (permisosCaller.includes(PermisoBanderas.AUTH_TODO)) return;
    const privilegiado = await this.rolesModel.esRolPrivilegiado(id);
    if (privilegiado) {
      throw new ForbiddenException(
        `Solo un usuario con auth.todo puede ${accion} el rol Administrador o roles con auth.todo`,
      );
    }
  }
}
