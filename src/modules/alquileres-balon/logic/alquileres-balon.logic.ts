import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateAlquileresBalonDto,
  FiltroAlquileresBalonDto,
  UpdateAlquileresBalonDto,
} from '../dto/alquileres-balon.dto';
import { AlquileresBalonModel } from '../models/alquileres-balon.model';

@Injectable()
export class AlquileresBalonLogic {
  constructor(private readonly model: AlquileresBalonModel) {}

  async listar(filtros: FiltroAlquileresBalonDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Alquiler ${id} no encontrado`);
  }

  async crear(dto: CreateAlquileresBalonDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdateAlquileresBalonDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Alquiler ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Alquiler ${id} no encontrado`);
  }
}
