import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateMovimientoInventarioDto,
  FiltroMovimientosInventarioDto,
  UpdateMovimientoInventarioDto,
} from '../dto/movimientos-inventario.dto';
import { MovimientosInventarioModel } from '../models/movimientos-inventario.model';

@Injectable()
export class MovimientosInventarioLogic {
  constructor(private readonly movimientosInventarioModel: MovimientosInventarioModel) {}

  async listar(filtros: FiltroMovimientosInventarioDto) {
    const result = await this.movimientosInventarioModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.movimientosInventarioModel.obtenerPorId(id);
    return mapSingleResult(result, `Movimiento ${id} no encontrado`);
  }

  async crear(dto: CreateMovimientoInventarioDto) {
    const result = await this.movimientosInventarioModel.crear(
      dto.fecha,
      dto.idProducto,
      dto.idAlmacen,
      dto.idTipoMovimiento,
      dto.cantidad,
      dto.idDocumentoRef ?? null,
      dto.idTipoDocumentoRef ?? null,
      dto.glosa ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo registrar el movimiento');
  }

  async actualizar(id: number, dto: UpdateMovimientoInventarioDto) {
    const result = await this.movimientosInventarioModel.actualizar(
      id,
      dto.fecha ?? null,
      dto.glosa ?? null,
      dto.idDocumentoRef ?? null,
      dto.idTipoDocumentoRef ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Movimiento ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.movimientosInventarioModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Movimiento ${id} no encontrado`);
  }
}
