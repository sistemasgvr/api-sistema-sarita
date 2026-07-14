import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateMantenimientosBalonDto,
  FiltroMantenimientosBalonDto,
  UpdateMantenimientosBalonDto,
} from '../dto/mantenimientos-balon.dto';
import { MantenimientosBalonModel } from '../models/mantenimientos-balon.model';

@Injectable()
export class MantenimientosBalonLogic {
  constructor(private readonly model: MantenimientosBalonModel) {}

  async listar(filtros: FiltroMantenimientosBalonDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Mantenimiento ${id} no encontrado`);
  }

  async crear(dto: CreateMantenimientosBalonDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdateMantenimientosBalonDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Mantenimiento ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Mantenimiento ${id} no encontrado`);
  }
}
