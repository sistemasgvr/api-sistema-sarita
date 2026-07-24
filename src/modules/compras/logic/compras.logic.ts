import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateCompraDto,
  FiltroComprasDto,
  UpdateCompraDto,
} from '../dto/compras.dto';
import { ComprasModel } from '../models/compras.model';

@Injectable()
export class ComprasLogic {
  constructor(private readonly comprasModel: ComprasModel) {}

  async listar(filtros: FiltroComprasDto) {
    const result = await this.comprasModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.comprasModel.obtenerPorId(id);
    return mapSingleResult(result, `Comprobante de compra ${id} no encontrado`);
  }

  async crear(dto: CreateCompraDto) {
    const result = await this.comprasModel.crear(dto);
    return mapSingleResult(result, 'No se pudo registrar el comprobante de compra');
  }

  async actualizar(id: number, dto: UpdateCompraDto) {
    const result = await this.comprasModel.actualizar(id, dto);
    return mapSingleResult(result, `Comprobante de compra ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.comprasModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Comprobante de compra ${id} no encontrado`);
  }
}