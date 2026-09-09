import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  ActividadItemDto,
  CrearRecojoOrigenDto,
  CrearRecojoPrestamoDto,
  FiltroActividadesDto,
  FiltroRankingActividadesDto,
  FiltroVencidosRecojoDto,
  GenerarRecojosDto,
  VerificarActividadDto,
} from '../dto/actividades.dto';

/** Resultado de un lote de escaneos sobre una actividad. */
export interface VerificacionActividadResult {
  error: string | null;
  registro: {
    momento: 'SALIDA' | 'LLEGADA';
    coincidencias: number;
    no_pertenecen: number;
    pendientes: number;
    observados: number;
    completo: boolean;
  } | null;
}

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
      filtros.idTipo ?? null,
      filtros.idPrioridad ?? null,
      filtros.sinResponsable ?? null,
    ]);
  }

  listarProximas(minutos = 60) {
    return this.db.callFunctionJson<AuthListResult>(
      'age_listar_actividades_proximas',
      [minutos],
    );
  }

  verificar(id: number, dto: VerificarActividadDto) {
    // La función SQL lee las claves en snake_case, como el resto del dominio.
    const lecturas = dto.lecturas.map((lectura) => ({
      codigo: lectura.codigo ?? null,
      id_item: lectura.idItem ?? null,
      cantidad: lectura.cantidad ?? null,
      conforme: lectura.conforme ?? true,
      observacion: lectura.observacion ?? null,
    }));

    return this.db.callFunctionJson<VerificacionActividadResult>(
      'age_registrar_verificacion',
      [
        id,
        dto.momento,
        JSON.stringify(lecturas),
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  iniciarEntrega(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('age_iniciar_entrega', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  culminarEntrega(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('age_culminar_entrega', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  listarVencidosRecojo(filtros: FiltroVencidosRecojoDto) {
    return this.db.callFunctionJson<AuthListResult>(
      'age_listar_vencidos_recojo',
      [filtros.buscar ?? '', filtros.limite ?? 30, filtros.offset],
    );
  }

  crearRecojoOrigen(dto: CrearRecojoOrigenDto) {
    return this.db.callFunctionJson<{
      error: string | null;
      registro: { id: number; creada: boolean; items: number } | null;
    }>('age_crear_recojo_origen', [
      dto.tipoOrigen,
      dto.idOrigen,
      dto.fechaProgramada ?? null,
      dto.horaInicioEstimada ?? null,
      dto.idTrabajadorResponsable ?? null,
      dto.observaciones ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  crearRecojoPrestamo(dto: CrearRecojoPrestamoDto) {
    return this.db.callFunctionJson<{
      error: string | null;
      registro: { id: number; creada: boolean; items: number } | null;
    }>('age_crear_recojo_prestamo', [
      dto.idPrestamo,
      dto.fechaProgramada ?? null,
      dto.horaInicioEstimada ?? null,
      dto.idTrabajadorResponsable ?? null,
      dto.observaciones ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  iniciarVerificacion(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<{
      error: string | null;
      registro: unknown;
    }>('age_iniciar_verificacion', [id, idUsuarioAuditoria ?? null]);
  }

  generarRecojosPorVencer(dto: GenerarRecojosDto) {
    return this.db.callFunctionJson<{
      error: string | null;
      registro: {
        dias_antes: number;
        creadas: number;
        ya_existian: number;
        id_actividades: number[];
      } | null;
    }>('age_generar_recojos_por_vencer', [
      dto.diasAntes ?? null,
      dto.idTrabajadorResponsable ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  ranking(filtros: FiltroRankingActividadesDto) {
    return this.db.callFunctionJson<AuthListResult>('age_ranking_usuarios', [
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.limite ?? 20,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('age_obtener_actividad', [
      id,
    ]);
  }

  crear(
    titulo: string | null,
    descripcion: string | null,
    fechaProgramada: Date | string,
    horaInicioEstimada: string | null,
    horaFinEstimada: string | null,
    idTipoActividad: number,
    idPrioridad: number,
    idCliente: number | null,
    idTrabajadorResponsable: number | null,
    idEstadoActividad: number,
    observaciones: string | null,
    idUsuarioAuditoria?: number,
    idComprobante?: number | null,
    idDocSalida?: number | null,
    items?: ActividadItemDto[] | null,
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
      idTrabajadorResponsable,
      idEstadoActividad,
      observaciones,
      idUsuarioAuditoria ?? null,
      idComprobante ?? null,
      idDocSalida ?? null,
      items?.length ? JSON.stringify(items) : null,
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
    idTrabajadorResponsable: number | null,
    idEstadoActividad: number | null,
    observaciones: string | null,
    idUsuarioAuditoria?: number,
    idComprobante?: number | null,
    idDocSalida?: number | null,
    items?: ActividadItemDto[] | null,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'age_actualizar_actividad',
      [
        id,
        titulo,
        descripcion,
        fechaProgramada,
        horaInicioEstimada,
        horaFinEstimada,
        null,
        idTipoActividad,
        idPrioridad,
        idCliente,
        idTrabajadorResponsable,
        idEstadoActividad,
        observaciones,
        idUsuarioAuditoria ?? null,
        idComprobante ?? null,
        idDocSalida ?? null,
        items ? JSON.stringify(items) : null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>(
      'age_eliminar_actividad',
      [id, idUsuarioAuditoria ?? null],
    );
  }

  marcarComoRealizada(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'age_cambiar_estado_actividad_realizada',
      [id, idUsuarioAuditoria ?? null],
    );
  }

  cancelar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'age_cancelar_actividad',
      [id, idUsuarioAuditoria ?? null],
    );
  }

  asignarResponsable(
    id: number,
    idUsuarioAuditoria?: number,
    idTrabajadorResponsable?: number | null,
    idTrabajadorApoyo?: number | null,
    liberar = false,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'age_asignar_responsable_actividad',
      [
        id,
        idUsuarioAuditoria ?? null,
        idTrabajadorResponsable ?? null,
        idTrabajadorApoyo ?? null,
        liberar,
      ],
    );
  }
}
