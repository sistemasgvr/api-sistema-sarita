import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateAlquileresDetalleDto,
  DevolverAlquileresDetalleDto,
  FiltroAlquileresDetalleDto,
  UpdateAlquileresDetalleDto,
} from '../dto/alquileres-detalle.dto';
import { AlquileresDetalleModel } from '../models/alquileres-detalle.model';

@Injectable()
export class AlquileresDetalleLogic {
  constructor(private readonly model: AlquileresDetalleModel) {}

  async listar(filtros: FiltroAlquileresDetalleDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Detalle de alquiler ${id} no encontrado`);
  }

  async crear(dto: CreateAlquileresDetalleDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdateAlquileresDetalleDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Detalle de alquiler ${id} no encontrado`);
  }

  async devolver(id: number, dto: DevolverAlquileresDetalleDto) {
    const result = await this.model.devolver(id, dto);
    return mapSingleResult(result, `Detalle de alquiler ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Detalle de alquiler ${id} no encontrado`);
  }
}
