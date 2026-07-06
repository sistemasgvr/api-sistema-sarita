import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateChoferDto,
  FiltroChoferDto,
  UpdateChoferDto,
} from '../dto/choferes.dto';
import { ChoferesModel } from '../models/choferes.model';

@Injectable()
export class ChoferesLogic {
  constructor(private readonly choferesModel: ChoferesModel) {}

  async listar(filtros: FiltroChoferDto) {
    const result = await this.choferesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.choferesModel.obtenerPorId(id);
    return mapSingleResult(result, `Chofer ${id} no encontrado`);
  }

  async crear(dto: CreateChoferDto) {
    const result = await this.choferesModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el chofer');
  }

  async actualizar(id: number, dto: UpdateChoferDto) {
    const result = await this.choferesModel.actualizar(id, dto);
    return mapSingleResult(result, `Chofer ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.choferesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Chofer ${id} no encontrado o ya está inactivo`);
  }
}
