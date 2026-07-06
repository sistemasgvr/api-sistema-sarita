import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateMovimientosBalonDto,
  FiltroMovimientosBalonDto,
  UpdateMovimientosBalonDto,
} from '../dto/movimientos-balon.dto';
import { MovimientosBalonModel } from '../models/movimientos-balon.model';

@Injectable()
export class MovimientosBalonLogic {
  constructor(private readonly model: MovimientosBalonModel) {}

  async listar(filtros: FiltroMovimientosBalonDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Movimiento de balón ${id} no encontrado`);
  }

  async crear(dto: CreateMovimientosBalonDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdateMovimientosBalonDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Movimiento de balón ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Movimiento de balón ${id} no encontrado`);
  }
}
