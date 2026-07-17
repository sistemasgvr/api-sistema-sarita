import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateStockDto,
  FiltroStockDto,
  UpdateStockDto,
} from '../dto/stock-producto.dto';
import { StockProductoModel } from '../models/stock-producto.model';

@Injectable()
export class StockProductoLogic {
  constructor(private readonly stockProductoModel: StockProductoModel) {}

  async listar(filtros: FiltroStockDto) {
    const result = await this.stockProductoModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.stockProductoModel.obtenerPorId(id);
    return mapSingleResult(result, `Stock ${id} no encontrado`);
  }

  async crear(dto: CreateStockDto) {
    const result = await this.stockProductoModel.crear(
      dto.idAlmacen,
      dto.idProducto,
      dto.stock ?? 0,
      dto.stockMinimo ?? 0,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo registrar el stock');
  }

  async actualizar(id: number, dto: UpdateStockDto) {
    const result = await this.stockProductoModel.actualizar(
      id,
      dto.stock ?? null,
      dto.stockMinimo ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Stock ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.stockProductoModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Stock ${id} no encontrado`);
  }
}
