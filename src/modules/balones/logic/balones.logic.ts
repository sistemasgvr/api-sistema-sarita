import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateBalonesDto,
  FiltroBalonesDto,
  UpdateBalonesDto,
} from '../dto/balones.dto';
import { BalonesModel } from '../models/balones.model';

@Injectable()
export class BalonesLogic {
  constructor(private readonly model: BalonesModel) {}

  async listar(filtros: FiltroBalonesDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Balón ${id} no encontrado`);
  }

  async crear(dto: CreateBalonesDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdateBalonesDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Balón ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Balón ${id} no encontrado`);
  }
}
