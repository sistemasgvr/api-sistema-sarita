import { Injectable, NotFoundException } from '@nestjs/common';
import { ActividadesModel } from '../models/actividades.model';
import {
  CreateActividadDto,
  FiltroActividadesDto,
  UpdateActividadDto,
} from '../dto/actividades.dto';

@Injectable()
export class ActividadesLogic {
  constructor(private readonly actividadesModel: ActividadesModel) {}

  async listar(filtros: FiltroActividadesDto) {
    return await this.actividadesModel.listar(filtros);
  }

  async obtenerPorId(id: number) {
    const res = await this.actividadesModel.obtenerPorId(id);
    if (!res || !res.registro) {
      throw new NotFoundException(`La actividad con ID ${id} no existe.`);
    }
    return res;
  }

  async crear(dto: CreateActividadDto) {
    return await this.actividadesModel.crear(dto);
  }

  async actualizar(id: number, dto: UpdateActividadDto) {
    const res = await this.actividadesModel.actualizar(id, dto);
    if (!res || !res.registro) {
      throw new NotFoundException(`La actividad con ID ${id} no existe.`);
    }
    return res;
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const res = await this.actividadesModel.eliminar(id, idUsuarioAuditoria);
    if (!res || !res.eliminado) {
      throw new NotFoundException(`La actividad con ID ${id} no existe.`);
    }
    return res;
  }
}