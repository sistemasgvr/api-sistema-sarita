import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateRecojosBalonDto,
  FiltroPendientesRecojoDto,
  FiltroRecojosBalonDto,
  RegistrarResultadoRecojoDto,
  UpdateRecojosBalonDto,
} from '../dto/recojos-balon.dto';

@Injectable()
export class RecojosBalonModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroRecojosBalonDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_recojos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idCliente ?? null,
      filtros.idPrestamo ?? null,
      filtros.idAlquiler ?? null,
      filtros.estadoNombre ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
    ]);
  }

  listarPendientes(filtros: FiltroPendientesRecojoDto) {
    return this.db.callFunctionJson<AuthListResult>(
      'bal_listar_pendientes_recojo',
      [
        filtros.buscar ?? '',
        filtros.limite ?? 10,
        filtros.offset,
        filtros.idCliente ?? null,
        filtros.tipoOrigen ?? null,
        filtros.fechaHasta ?? null,
      ],
    );
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_recojo', [id]);
  }

  crear(dto: CreateRecojosBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_recojo', [
      dto.idCliente ?? null,
      dto.idPrestamo ?? null,
      dto.idAlquiler ?? null,
      dto.fechaProgramada ?? null,
      dto.horaEstimada ?? null,
      dto.idUsuarioResponsable ?? null,
      dto.observacion ?? null,
      JSON.stringify(
        (dto.detalles ?? []).map((d) => ({
          id_prestamo_detalle: d.idPrestamoDetalle,
          id_alquiler_detalle: d.idAlquilerDetalle,
          observacion: d.observacion ?? null,
        })),
      ),
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateRecojosBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_actualizar_recojo', [
      id,
      dto.idPrestamo ?? null,
      dto.idAlquiler ?? null,
      dto.fechaProgramada ?? null,
      dto.horaEstimada ?? null,
      dto.idUsuarioResponsable ?? null,
      dto.estadoNombre ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  async resolverIdMotivoFallo(
    idMotivoFallo?: number | null,
    motivoFalloNombre?: string | null,
  ): Promise<number | null> {
    if (idMotivoFallo) return idMotivoFallo;
    const nombre = motivoFalloNombre?.trim().toUpperCase();
    if (!nombre) return null;
    const result = await this.db.query<{ id: number }>(
      `SELECT lo.id
       FROM gen_lista_opciones lo
       INNER JOIN gen_lista l ON l.id = lo.id_lista
       WHERE l.nombre = 'MotivoFalloRecojo'
         AND UPPER(lo.nombre) = $1
         AND lo.estado = 1
       LIMIT 1`,
      [nombre],
    );
    return result.rows[0]?.id ?? null;
  }

  async registrarResultado(id: number, dto: RegistrarResultadoRecojoDto) {
    const idMotivo = await this.resolverIdMotivoFallo(
      dto.idMotivoFallo,
      dto.motivoFalloNombre,
    );
    return this.db.callFunctionJson<AuthSingleResult>(
      'bal_registrar_resultado_recojo',
      [
        id,
        dto.fechaVisita ?? null,
        idMotivo,
        dto.observacion ?? null,
        JSON.stringify(
          (dto.detalles ?? []).map((d) => ({
            id_prestamo_detalle: d.idPrestamoDetalle,
            id_alquiler_detalle: d.idAlquilerDetalle,
            resultado: d.resultado,
            nombre_estado_contenido: d.nombreEstadoContenido ?? null,
            cantidad_restante: d.cantidadRestante ?? null,
            nueva_fecha_retorno: d.nuevaFechaRetorno ?? null,
            id_almacen_destino: d.idAlmacenDestino ?? null,
            observacion: d.observacion ?? null,
          })),
        ),
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_recojo', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
