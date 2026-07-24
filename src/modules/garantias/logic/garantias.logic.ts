import { Injectable } from '@nestjs/common';
import {
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateGarantiaDto,
  DevolverGarantiaDto,
  FiltroGarantiasDto,
} from '../dto/garantias.dto';
import { GarantiasModel } from '../models/garantias.model';

@Injectable()
export class GarantiasLogic {
  constructor(private readonly model: GarantiasModel) {}

  async listar(filtros: FiltroGarantiasDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Garantía ${id} no encontrada`);
  }

  async crear(dto: CreateGarantiaDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo registrar la garantía');
  }

  async devolver(id: number, dto: DevolverGarantiaDto) {
    const result = await this.model.devolver(id, dto);
    return mapSingleResult(result, `Garantía ${id} no encontrada`);
  }
}
