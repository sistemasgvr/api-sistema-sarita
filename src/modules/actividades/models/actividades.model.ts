import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroActividadesDto } from '../dto/actividades.dto';

@Injectable()
export class ActividadesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroActividadesDto) {
    return this.db.callFunctionJson<AuthListResult>('age_listar_actividades', [
      filtros.buscar ?? '', 
      filtros.limite ?? 10,
      filtros.offset,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.idEstado ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('age_obtener_actividad', [
      id,
    ]);
  }

  crear(
    titulo: string,
    descripcion: string | null,
    fechaProgramada: Date | string,
    horaInicioEstimada: string | null,
    horaFinEstimada: string | null,
    idTipoActividad: number,
    idPrioridad: number,
    idCliente: number | null,
    idUsuarioResponsable: number | null,
    idEstadoActividad: number,
    observaciones: string | null,
    idUsuarioAuditoria?: number, 
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('age_crear_actividad', [
      titulo,
      descripcion,
      fechaProgramada,
      horaInicioEstimada,
      horaFinEstimada,
      idTipoActividad,
      idPrioridad,
      idCliente,
      idUsuarioResponsable,
      idEstadoActividad,
      observaciones,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    titulo: string | null,
    descripcion: string | null,
    fechaProgramada: Date | string | null,
    horaInicioEstimada: string | null,
    horaFinEstimada: string | null,
    idTipoActividad: number | null,
    idPrioridad: number | null,
    idCliente: number | null,
    idUsuarioResponsable: number | null,
    idEstadoActividad: number | null,
    observaciones: string | null,
    idUsuarioAuditoria?: number, 
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('age_actualizar_actividad', [
      id,
      titulo,
      descripcion,
      fechaProgramada,
      horaInicioEstimada,
      horaFinEstimada,
      idTipoActividad,
      idPrioridad,
      idCliente,
      idUsuarioResponsable,
      idEstadoActividad,
      observaciones,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) { 
    return this.db.callFunctionJson<AuthDeleteResult>('age_eliminar_actividad', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  marcarComoRealizada(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('age_cambiar_estado_actividad_realizada', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}