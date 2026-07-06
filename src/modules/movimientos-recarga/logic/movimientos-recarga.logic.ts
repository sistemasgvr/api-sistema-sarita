import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateMovimientosRecargaDto,
  FiltroMovimientosRecargaDto,
  UpdateMovimientosRecargaDto,
} from '../dto/movimientos-recarga.dto';
import { MovimientosRecargaModel } from '../models/movimientos-recarga.model';

@Injectable()
export class MovimientosRecargaLogic {
  constructor(private readonly model: MovimientosRecargaModel) {}

  async listar(filtros: FiltroMovimientosRecargaDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Movimiento de recarga ${id} no encontrado`);
  }

  async crear(dto: CreateMovimientosRecargaDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdateMovimientosRecargaDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Movimiento de recarga ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Movimiento de recarga ${id} no encontrado`);
  }
}
