import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateDireccionDto,
  FiltroDireccionesDto,
  UpdateDireccionDto,
} from '../dto/filtros-direcciones.dto';
import { DireccionesModel } from '../models/direcciones.modele';

@Injectable()
export class DireccionesLogic {
  constructor(private readonly direccionesModel: DireccionesModel) {}

  async listar(filtros: FiltroDireccionesDto) {
    const result = await this.direccionesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.direccionesModel.obtenerPorId(id);
    return mapSingleResult(result, `Dirección ${id} no encontrada`);
  }

  async crear(dto: CreateDireccionDto) {
    const result = await this.direccionesModel.crear(
      dto.idCliente,
      dto.direccion,
      dto.descripcion ?? null,
      dto.idDepartamento ?? null,
      dto.idProvincia ?? null,
      dto.idDistrito ?? null,
      dto.referencia ?? null,
      dto.esPrincipal ?? false,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la dirección');
  }

  async actualizar(id: number, dto: UpdateDireccionDto) {
    const result = await this.direccionesModel.actualizar(
      id,
      dto.direccion ?? null,
      dto.descripcion ?? null,
      dto.idDepartamento ?? null,
      dto.idProvincia ?? null,
      dto.idDistrito ?? null,
      dto.referencia ?? null,
      dto.esPrincipal ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Dirección ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.direccionesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Dirección ${id} no encontrada`);
  }
}
