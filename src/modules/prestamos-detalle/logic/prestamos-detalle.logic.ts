import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreatePrestamosDetalleDto,
  DevolverPrestamosDetalleDto,
  FiltroPrestamosDetalleDto,
  UpdatePrestamosDetalleDto,
} from '../dto/prestamos-detalle.dto';
import { PrestamosDetalleModel } from '../models/prestamos-detalle.model';

@Injectable()
export class PrestamosDetalleLogic {
  constructor(private readonly model: PrestamosDetalleModel) {}

  async listar(filtros: FiltroPrestamosDetalleDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Detalle de préstamo ${id} no encontrado`);
  }

  async crear(dto: CreatePrestamosDetalleDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdatePrestamosDetalleDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Detalle de préstamo ${id} no encontrado`);
  }

  async devolver(id: number, dto: DevolverPrestamosDetalleDto) {
    const result = await this.model.devolver(id, dto);
    return mapSingleResult(result, `Detalle de préstamo ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Detalle de préstamo ${id} no encontrado`);
  }
}
