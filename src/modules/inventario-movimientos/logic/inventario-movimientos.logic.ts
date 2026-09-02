import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateInventarioMovimientoDto,
  FiltroInventarioMovimientosDto,
} from '../dto/inventario-movimientos.dto';
import { InventarioMovimientosModel } from '../models/inventario-movimientos.model';

@Injectable()
export class InventarioMovimientosLogic {
  constructor(private readonly inventarioMovimientosModel: InventarioMovimientosModel) {}

  async listar(filtros: FiltroInventarioMovimientosDto) {
    const result = await this.inventarioMovimientosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.inventarioMovimientosModel.obtenerPorId(id);
    return mapSingleResult(result, `Movimiento ${id} no encontrado`);
  }

  async crear(dto: CreateInventarioMovimientoDto) {
    const result = await this.inventarioMovimientosModel.crear(dto);
    return mapSingleResult(result, 'No se pudo registrar el movimiento');
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.inventarioMovimientosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Movimiento ${id} no encontrado`);
  }
}
