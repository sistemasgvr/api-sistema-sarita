import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateSucursalDto, UpdateSucursalDto } from '../dto/sucursales.dto';
import { SucursalesModel } from '../models/sucursales.model';

@Injectable()
export class SucursalesLogic {
  constructor(private readonly sucursalesModel: SucursalesModel) {}

  async listar(filtros: FiltroPaginacionDto) {
    const result = await this.sucursalesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.sucursalesModel.obtenerPorId(id);
    return mapSingleResult(result, `Sucursal ${id} no encontrada`);
  }

  async crear(dto: CreateSucursalDto) {
    const result = await this.sucursalesModel.crear(
      dto.codigo,
      dto.nombre,
      dto.direccion ?? null,
      dto.idDepartamento ?? null,
      dto.idProvincia ?? null,
      dto.idDistrito ?? null,
      dto.telefono ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la sucursal');
  }

  async actualizar(id: number, dto: UpdateSucursalDto) {
    const result = await this.sucursalesModel.actualizar(
      id,
      dto.codigo ?? null,
      dto.nombre ?? null,
      dto.direccion ?? null,
      dto.idDepartamento ?? null,
      dto.idProvincia ?? null,
      dto.idDistrito ?? null,
      dto.telefono ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Sucursal ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.sucursalesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Sucursal ${id} no encontrada`);
  }
}
