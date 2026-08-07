import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateRecargaPlantaDto,
  FiltroRecargasPlantaDto,
  UpdateRecargaPlantaDto,
} from '../dto/recargas-planta.dto';
import { RecargasPlantaModel } from '../models/recargas-planta.model';

@Injectable()
export class RecargasPlantaLogic {
  constructor(private readonly model: RecargasPlantaModel) {}

  async listar(filtros: FiltroRecargasPlantaDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Orden de recarga ${id} no encontrada`);
  }

  async crear(dto: CreateRecargaPlantaDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear la orden de recarga');
  }

  async actualizar(id: number, dto: UpdateRecargaPlantaDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Orden de recarga ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Orden de recarga ${id} no encontrada`);
  }
}
