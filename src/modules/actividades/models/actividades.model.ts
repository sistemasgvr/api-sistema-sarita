import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { AuthDeleteResult, AuthListResult, AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { CreateActividadDto, UpdateActividadDto, FiltroActividadesDto } from '../dto/actividades.dto';

@Injectable()
export class ActividadesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroActividadesDto) {
    return this.db.callFunctionJson<AuthListResult>('age_listar_actividades', [
      filtros.buscar ?? '',
      filtros.limite ? Number(filtros.limite) : 10,
      filtros.offset ? Number(filtros.offset) : 0,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.idEstado ? Number(filtros.idEstado) : null, 
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('age_obtener_actividad', [id]);
  }

  crear(dto: CreateActividadDto) {
    return this.db.callFunctionJson<AuthSingleResult>('age_crear_actividad', [
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
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateActividadDto) {
    return this.db.callFunctionJson<AuthSingleResult>('age_actualizar_actividad', [
      id,
      dto.titulo ?? null,
      dto.descripcion ?? null,
      dto.fechaProgramada ?? null,
      dto.horaInicioEstimada ?? null,
      dto.horaFinEstimada ?? null,
      dto.fechaHoraCierre ?? null,
      dto.idTipoActividad ?? null,
      dto.idPrioridad ?? null, 
      dto.idCliente ?? null,
      dto.idUsuarioResponsable ?? null,
      dto.idEstadoActividad ?? null, 
      dto.observaciones ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('age_eliminar_actividad', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}