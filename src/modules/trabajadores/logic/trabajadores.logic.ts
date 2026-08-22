import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateTrabajadorDto,
  FiltroTrabajadorDto,
  UpdateTrabajadorDto,
} from '../dto/trabajadores.dto';
import { TrabajadoresModel } from '../models/trabajadores.model';

@Injectable()
export class TrabajadoresLogic {
  constructor(private readonly trabajadoresModel: TrabajadoresModel) {}

  async listar(filtros: FiltroTrabajadorDto) {
    const result = await this.trabajadoresModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.trabajadoresModel.obtenerPorId(id);
    return mapSingleResult(result, `Trabajador ${id} no encontrado`);
  }

  async crear(dto: CreateTrabajadorDto) {
    const result = await this.trabajadoresModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el trabajador');
  }

  async actualizar(id: number, dto: UpdateTrabajadorDto) {
    const result = await this.trabajadoresModel.actualizar(id, dto);
    return mapSingleResult(result, `Trabajador ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.trabajadoresModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Trabajador ${id} no encontrado o ya está inactivo`);
  }
}
