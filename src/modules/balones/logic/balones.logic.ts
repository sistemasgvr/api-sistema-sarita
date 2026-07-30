import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  TipoNotificacion,
  TipoReferenciaNotificacion,
} from '../../notificaciones/constants/tipo-notificacion';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import {
  CreateBalonesDto,
  AprobarBajaBalonDto,
  DarBajaBalonDto,
  FiltroBalonesDto,
  FiltroEstadoHistorialDto,
  FiltroPhHistorialDto,
  RechazarBajaBalonDto,
  RegistrarPhHistorialDto,
  RestaurarBalonDto,
  UpdateBalonesDto,
} from '../dto/balones.dto';
import { BalonesModel } from '../models/balones.model';

@Injectable()
export class BalonesLogic {
  private readonly logger = new Logger(BalonesLogic.name);

  constructor(
    private readonly model: BalonesModel,
    private readonly notificacionesLogic: NotificacionesLogic,
  ) {}

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

  async listarPhHistorial(idBalon: number, filtros: FiltroPhHistorialDto) {
    const result = await this.model.listarPhHistorial(idBalon, filtros);
    return mapListResult(result, filtros);
  }

  async registrarPhHistorial(idBalon: number, dto: RegistrarPhHistorialDto) {
    const result = await this.model.registrarPhHistorial(idBalon, dto);
    return mapSingleResult(result, 'No se pudo registrar la prueba hidrostática');
  }

  async obtenerBajaPorBalon(idBalon: number) {
    const result = await this.model.obtenerBajaPorBalon(idBalon);

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    return result.registro ?? null;
  }

  async darBaja(idBalon: number, dto: DarBajaBalonDto) {
    const result = await this.model.darBaja(idBalon, dto);
    const registro = mapSingleResult(
      result,
      'No se pudo registrar la solicitud de baja',
    ) as Record<string, unknown>;

    void this.notificarSolicitudBajaCilindro(registro, dto).catch((error: unknown) => {
      this.logger.warn(
        `No se pudo notificar baja de cilindro: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    });

    return registro;
  }

  async listarSolicitudesBaja(filtros: FiltroPaginacionDto) {
    const result = await this.model.listarSolicitudesBaja(filtros);
    return mapListResult(result, filtros);
  }

  async aprobarBaja(idBaja: number, dto: AprobarBajaBalonDto) {
    const result = await this.model.aprobarBaja(idBaja, dto);
    return mapSingleResult(result, 'No se pudo aprobar la solicitud de baja');
  }

  async rechazarBaja(idBaja: number, dto: RechazarBajaBalonDto) {
    const result = await this.model.rechazarBaja(idBaja, dto);
    return mapSingleResult(result, 'No se pudo rechazar la solicitud de baja');
  }

  async listarEstadoHistorial(idBalon: number, filtros: FiltroEstadoHistorialDto) {
    const result = await this.model.listarEstadoHistorial(idBalon, filtros);
    return mapListResult(result, filtros);
  }

  async restaurar(idBalon: number, dto: RestaurarBalonDto) {
    const result = await this.model.restaurar(idBalon, dto);
    return mapSingleResult(result, 'No se pudo reactivar el cilindro');
  }

  private async notificarSolicitudBajaCilindro(
    registro: Record<string, unknown>,
    dto: DarBajaBalonDto,
  ) {
    const idBaja = Number(registro.id);
    const codigo = String(registro.codigo_balon ?? registro.id_balon ?? 'N/D');
    const solicitante = String(registro.nombre_usuario_solicita ?? 'Un usuario');
    const motivo = String(registro.nombre_motivo_baja ?? 'Sin motivo');
    const hoy = new Date().toISOString().slice(0, 10);

    await this.notificacionesLogic.notificarPorPermiso({
      permiso: PermisoBanderas.BAJAS_BALON_APROBAR,
      codigoTipo: TipoNotificacion.BAJA_CILINDRO_SOLICITADA,
      titulo: 'Solicitud de baja de cilindro',
      mensaje: `${solicitante} solicitó baja del cilindro ${codigo} (motivo: ${motivo}).`,
      payload: {
        idBaja,
        idBalon: registro.id_balon,
        codigoBalon: registro.codigo_balon,
        idMotivoBaja: registro.id_motivo_baja,
        nombreMotivoBaja: registro.nombre_motivo_baja,
        idUsuarioSolicita: registro.id_usuario_solicita,
      },
      idReferencia: idBaja,
      tipoReferencia: TipoReferenciaNotificacion.BALON,
      claveDedupePrefix: `BAJA_CILINDRO_SOLICITADA:${idBaja}:${hoy}`,
      excluirUsuarioId: dto.idUsuarioSolicita ?? dto.idUsuarioAuditoria,
      idUsuarioAuditoria: dto.idUsuarioAuditoria ?? dto.idUsuarioSolicita,
      soloAdmins: true,
    });
  }
}
