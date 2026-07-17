import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateTiposBalonDto,
  FiltroTiposBalonDto,
  UpdateTiposBalonDto,
} from '../dto/tipos-balon.dto';
import { TiposBalonModel } from '../models/tipos-balon.model';

@Injectable()
export class TiposBalonLogic {
  constructor(private readonly model: TiposBalonModel) {}

  async listar(filtros: FiltroTiposBalonDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Tipo de balón ${id} no encontrado`);
  }

  async crear(dto: CreateTiposBalonDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdateTiposBalonDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Tipo de balón ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Tipo de balón ${id} no encontrado`);
  }
}
