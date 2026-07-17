import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateActividadDto,
  FiltroActividadesDto,
  UpdateActividadDto,
} from '../dto/actividades.dto';
import { ActividadesModel } from '../models/actividades.model';

@Injectable()
export class ActividadesLogic {
  constructor(private readonly actividadesModel: ActividadesModel) {}

  async listar(filtros: FiltroActividadesDto) {
    const result = await this.actividadesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.actividadesModel.obtenerPorId(id);
    return mapSingleResult(result, `Actividad ${id} no encontrada`);
  }

  async crear(dto: CreateActividadDto) {
    const result = await this.actividadesModel.crear(
      dto.titulo,
      dto.descripcion ?? null,
      dto.fechaProgramada,
      dto.horaInicioEstimada ?? null,
      dto.horaFinEstimada ?? null,
      dto.idTipoActividad,
      dto.idPrioridad,
      dto.idCliente ?? null,
      dto.idUsuarioResponsable ?? null,
      dto.idEstadoActividad,
      dto.observaciones ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la actividad');
  }

  async actualizar(id: number, dto: UpdateActividadDto) {
    const result = await this.actividadesModel.actualizar(
      id,
      dto.titulo ?? null,
      dto.descripcion ?? null,
      dto.fechaProgramada ?? null,
      dto.horaInicioEstimada ?? null,
      dto.horaFinEstimada ?? null,
      dto.idTipoActividad ?? null,
      dto.idPrioridad ?? null,
      dto.idCliente ?? null,
      dto.idUsuarioResponsable ?? null,
      dto.idEstadoActividad ?? null,
      dto.observaciones ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Actividad ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.actividadesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Actividad ${id} no encontrada`);
  }
}