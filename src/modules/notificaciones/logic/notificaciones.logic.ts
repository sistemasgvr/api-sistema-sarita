import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import {
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  TipoNotificacion,
  TipoReferenciaNotificacion,
} from '../constants/tipo-notificacion';
import {
  CrearNotificacionDto,
  FiltroNotificacionesDto,
} from '../dto/notificaciones.dto';
import { NotificacionesGateway } from '../gateways/notificaciones.gateway';
import { NotificacionesModel } from '../models/notificaciones.model';

export interface NotificacionRegistro {
  id: number;
  id_usuario: number;
  codigo_tipo: string;
  titulo: string;
  mensaje?: string | null;
  payload?: Record<string, unknown>;
  id_referencia?: number | null;
  tipo_referencia?: string | null;
  clave_dedupe?: string | null;
  leida: boolean;
  fecha_lectura?: string | null;
  fecha_creacion?: string;
}

interface AlquilerVencidoRow {
  id: number;
  nombre_cliente?: string | null;
  fecha_vencimiento?: string;
  dias_vencido?: number;
  id_periodo?: number | null;
  numero_periodo?: number | null;
}

@Injectable()
export class NotificacionesLogic {
  private readonly logger = new Logger(NotificacionesLogic.name);

  constructor(
    private readonly model: NotificacionesModel,
    private readonly gateway: NotificacionesGateway,
  ) {}

  async listar(idUsuario: number, filtros: FiltroNotificacionesDto) {
    const result = await this.model.listar(idUsuario, filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number, idUsuario: number) {
    const result = await this.model.obtenerPorId(id, idUsuario);
    return mapSingleResult(result, `Notificación ${id} no encontrada`);
  }

  async contarNoLeidas(idUsuario: number) {
    const result = await this.model.contarNoLeidas(idUsuario);
    return { total: result.total ?? 0 };
  }

  async marcarLeida(id: number, idUsuario: number) {
    const result = await this.model.marcarLeida(id, idUsuario, idUsuario);
    return mapSingleResult(result, `Notificación ${id} no encontrada`);
  }

  async marcarTodasLeidas(idUsuario: number) {
    const result = await this.model.marcarTodasLeidas(idUsuario, idUsuario);
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return { actualizadas: result.actualizadas ?? 0 };
  }

  /**
   * API genérica: notifica a usuario(s), roles y/o quienes tienen un permiso.
   */
  async enviar(dto: CrearNotificacionDto, idUsuarioAuditoria?: number) {
    const destinatarios = await this.resolverDestinatarios(dto);
    if (destinatarios.length === 0) {
      throw new BadRequestException('No se encontraron destinatarios');
    }

    const creadas: NotificacionRegistro[] = [];
    for (const idUsuario of destinatarios) {
      const registro = await this.crearYEmitir({
        idUsuario,
        codigoTipo: dto.codigoTipo,
        titulo: dto.titulo,
        mensaje: dto.mensaje,
        payload: dto.payload,
        idReferencia: dto.idReferencia,
        tipoReferencia: dto.tipoReferencia,
        claveDedupe: dto.claveDedupe,
        idUsuarioAuditoria,
      });
      if (registro) creadas.push(registro);
    }

    return {
      destinatarios: destinatarios.length,
      creadas: creadas.length,
      registros: creadas,
    };
  }

  async crearYEmitir(params: {
    idUsuario: number;
    codigoTipo: string;
    titulo: string;
    mensaje?: string;
    payload?: Record<string, unknown>;
    idReferencia?: number;
    tipoReferencia?: string;
    claveDedupe?: string;
    idUsuarioAuditoria?: number;
  }): Promise<NotificacionRegistro | null> {
    const result = await this.model.crear({
      idUsuario: params.idUsuario,
      codigoTipo: params.codigoTipo,
      titulo: params.titulo,
      mensaje: params.mensaje ?? null,
      payload: params.payload ?? {},
      idReferencia: params.idReferencia ?? null,
      tipoReferencia: params.tipoReferencia ?? null,
      claveDedupe: params.claveDedupe ?? null,
      idUsuarioAuditoria: params.idUsuarioAuditoria ?? null,
    });

    if (result.error || !result.registro) {
      this.logger.warn(
        `No se creó notificación para user ${params.idUsuario}: ${result.error ?? 'sin registro'}`,
      );
      return null;
    }

    const registro = result.registro as NotificacionRegistro;
    // Solo push en tiempo real si es nueva (dedupe no re-emite)
    if (result.creada !== false) {
      this.gateway.emitToUser(params.idUsuario, registro);
    }
    return result.creada === false ? null : registro;
  }

  async detectarYNotificarAlquileresVencidos(idUsuarioAuditoria?: number) {
    const raw = await this.model.listarAlquileresVencidos();
    const alquileres = (raw.registros ?? []) as AlquilerVencidoRow[];

    const destinatariosResult = await this.model.listarIdsPorPermiso(
      PermisoBanderas.ALQUILERES_BALON_LISTAR,
    );
    const destinatarios = this.normalizeIds(destinatariosResult.ids);

    if (destinatarios.length === 0) {
      return {
        alquileres: alquileres.length,
        destinatarios: 0,
        notificaciones: 0,
      };
    }

    const hoy = new Date().toISOString().slice(0, 10);
    let notificaciones = 0;

    for (const alquiler of alquileres) {
      const nombre = alquiler.nombre_cliente?.trim() || `Alquiler #${alquiler.id}`;
      const dias = Number(alquiler.dias_vencido ?? 0);
      const titulo = 'Alquiler vencido';
      const mensaje =
        dias > 0
          ? `${nombre} venció hace ${dias} día(s) (${alquiler.fecha_vencimiento}).`
          : `${nombre} tiene la fecha de vencimiento ${alquiler.fecha_vencimiento}.`;

      for (const idUsuario of destinatarios) {
        const creado = await this.crearYEmitir({
          idUsuario,
          codigoTipo: TipoNotificacion.ALQUILER_VENCIDO,
          titulo,
          mensaje,
          payload: {
            idAlquiler: alquiler.id,
            idPeriodo: alquiler.id_periodo,
            numeroPeriodo: alquiler.numero_periodo,
            fechaVencimiento: alquiler.fecha_vencimiento,
            diasVencido: dias,
            nombreCliente: alquiler.nombre_cliente,
          },
          idReferencia: alquiler.id,
          tipoReferencia: TipoReferenciaNotificacion.ALQUILER,
          claveDedupe: `ALQUILER_VENCIDO:${alquiler.id}:${hoy}`,
          idUsuarioAuditoria,
        });
        if (creado) notificaciones += 1;
      }
    }

    this.logger.log(
      `Alquileres vencidos: ${alquileres.length} | destinatarios: ${destinatarios.length} | notifs: ${notificaciones}`,
    );

    return {
      alquileres: alquileres.length,
      destinatarios: destinatarios.length,
      notificaciones,
    };
  }

  private async resolverDestinatarios(dto: CrearNotificacionDto): Promise<number[]> {
    const ids = new Set<number>();

    if (dto.idUsuario) ids.add(dto.idUsuario);
    for (const id of dto.idsUsuarios ?? []) {
      if (id) ids.add(id);
    }

    if (dto.idsRoles?.length) {
      const byRoles = await this.model.listarIdsPorRoles(dto.idsRoles);
      for (const id of this.normalizeIds(byRoles.ids)) ids.add(id);
    }

    if (dto.permiso?.trim()) {
      const byPermiso = await this.model.listarIdsPorPermiso(dto.permiso.trim());
      for (const id of this.normalizeIds(byPermiso.ids)) ids.add(id);
    }

    return [...ids];
  }

  private normalizeIds(ids: unknown): number[] {
    if (!Array.isArray(ids)) return [];
    return ids
      .map((id) => Number(id))
      .filter((id) => Number.isInteger(id) && id > 0);
  }
}
