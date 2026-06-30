import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateCondicionPagoDto,
  UpdateCondicionPagoDto,
} from '../dto/condiciones-pago.dto';
import { CondicionesPagoModel } from '../models/condiciones-pago.model';

@Injectable()
export class CondicionesPagoLogic {
  constructor(private readonly condicionesPagoModel: CondicionesPagoModel) {}

  async listar(filtros: FiltroPaginacionDto) {
    const result = await this.condicionesPagoModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.condicionesPagoModel.obtenerPorId(id);
    return mapSingleResult(result, `Condición de pago ${id} no encontrada`);
  }

  async crear(dto: CreateCondicionPagoDto) {
    const result = await this.condicionesPagoModel.crear(
      dto.codigo,
      dto.nombre,
      dto.diasCredito,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la condición de pago');
  }

  async actualizar(id: number, dto: UpdateCondicionPagoDto) {
    const result = await this.condicionesPagoModel.actualizar(
      id,
      dto.codigo ?? null,
      dto.nombre ?? null,
      dto.diasCredito ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Condición de pago ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.condicionesPagoModel.eliminar(
      id,
      idUsuarioAuditoria,
    );
    return mapDeleteResult(result, `Condición de pago ${id} no encontrada`);
  }
}
