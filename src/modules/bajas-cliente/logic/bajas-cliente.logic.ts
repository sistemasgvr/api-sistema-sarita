import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ClientesLogic } from '../../clientes/logic/clientes.logic';
import { esClientesVarios } from '../../clientes/constants/clientes-varios';
import {
  TipoNotificacion,
  TipoReferenciaNotificacion,
} from '../../notificaciones/constants/tipo-notificacion';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import {
  FiltroBajaClienteDto,
  SolicitarBajaClienteDto,
  SolicitarReactivacionClienteDto,
} from '../dto/bajas-cliente.dto';
import { BajasClienteModel } from '../models/bajas-cliente.model';

@Injectable()
export class BajasClienteLogic {
  private readonly logger = new Logger(BajasClienteLogic.name);

  constructor(
    private readonly bajasClienteModel: BajasClienteModel,
    private readonly clientesLogic: ClientesLogic,
    private readonly notificacionesLogic: NotificacionesLogic,
  ) {}

  async listar(filtros: FiltroBajaClienteDto) {
    const result = await this.bajasClienteModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.bajasClienteModel.obtenerPorId(id);
    return mapSingleResult(result, `Solicitud de baja ${id} no encontrada`);
  }

  private async assertNoEsClientesVarios(idCliente: number) {
    const cliente = await this.clientesLogic.obtenerPorId(idCliente);
    if (esClientesVarios(cliente as { codigo_interno?: string | null })) {
      throw new BadRequestException(
        'No se puede solicitar baja/reactivación del cliente de sistema Clientes Varios (CVARIOS)',
      );
    }
  }

  private async resolverTipoSolicitudReactivacion(
    idTipoSolicitud?: number,
  ): Promise<number> {
    if (idTipoSolicitud != null) {
      return idTipoSolicitud;
    }
    const id = await this.bajasClienteModel.resolverIdTipoSolicitud('REACTIVACION');
    if (id == null) {
      throw new BadRequestException(
        'No se encontró el tipo de solicitud REACTIVACION en el catálogo',
      );
    }
    return id;
  }

  async solicitarReactivacion(dto: SolicitarReactivacionClienteDto) {
    await this.assertNoEsClientesVarios(dto.idCliente);
    const result = await this.bajasClienteModel.solicitarReactivacion({
      ...dto,
      idTipoSolicitud: await this.resolverTipoSolicitudReactivacion(
        dto.idTipoSolicitud,
      ),
    });
    const registro = mapSingleResult(
      result,
      'No se pudo crear la solicitud de reactivación',
    ) as Record<string, unknown>;

    void this.notificarSolicitudCliente(registro, dto, 'reactivacion').catch(
      (error: unknown) => {
        this.logger.warn(
          `No se pudo notificar reactivación de cliente: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      },
    );

    return registro;
  }

  async solicitar(dto: SolicitarBajaClienteDto) {
    await this.assertNoEsClientesVarios(dto.idCliente);
    const result = await this.bajasClienteModel.solicitar(dto);
    const registro = mapSingleResult(
      result,
      'No se pudo crear la solicitud de baja',
    ) as Record<string, unknown>;

    void this.notificarSolicitudCliente(registro, dto, 'baja').catch(
      (error: unknown) => {
        this.logger.warn(
          `No se pudo notificar baja de cliente: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      },
    );

    return registro;
  }

  async aprobar(idBaja: number, idUsuarioAuditoria?: number) {
    const result = await this.bajasClienteModel.aprobar(idBaja, idUsuarioAuditoria);
    const registro = mapSingleResult(
      result,
      `Solicitud de baja ${idBaja} no encontrada`,
    ) as Record<string, unknown>;

    void this.notificarResultadoCliente(registro, 'aprobada', idUsuarioAuditoria).catch(
      (error: unknown) => {
        this.logger.warn(
          `No se pudo notificar aprobación de baja cliente: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      },
    );

    return registro;
  }

  async rechazar(idBaja: number, idUsuarioAuditoria?: number) {
    const result = await this.bajasClienteModel.rechazar(idBaja, idUsuarioAuditoria);
    const registro = mapSingleResult(
      result,
      `Solicitud de baja ${idBaja} no encontrada`,
    ) as Record<string, unknown>;

    void this.notificarResultadoCliente(registro, 'rechazada', idUsuarioAuditoria).catch(
      (error: unknown) => {
        this.logger.warn(
          `No se pudo notificar rechazo de baja cliente: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      },
    );

    return registro;
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.bajasClienteModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Solicitud de baja ${id} no encontrada`);
  }

  private async notificarResultadoCliente(
    registro: Record<string, unknown>,
    resultado: 'aprobada' | 'rechazada',
    idUsuarioAuditoria?: number,
  ) {
    const idSolicitante = Number(registro.id_usuario_solicita);
    if (!Number.isInteger(idSolicitante) || idSolicitante <= 0) return;

    const idBaja = Number(registro.id);
    const cliente = this.nombreCliente(registro);
    const esReactivacion =
      String(registro.nombre_tipo_solicitud ?? '').toUpperCase() === 'REACTIVACION';
    const aprobada = resultado === 'aprobada';
    const hoy = new Date().toISOString().slice(0, 10);

    let codigoTipo: string;
    let titulo: string;
    let mensaje: string;

    if (esReactivacion) {
      codigoTipo = aprobada
        ? TipoNotificacion.REACTIVACION_CLIENTE_APROBADA
        : TipoNotificacion.REACTIVACION_CLIENTE_RECHAZADA;
      titulo = aprobada
        ? 'Reactivación de cliente aprobada'
        : 'Reactivación de cliente rechazada';
      mensaje = aprobada
        ? `Tu solicitud de reactivación de ${cliente} fue aprobada.`
        : `Tu solicitud de reactivación de ${cliente} fue rechazada.`;
    } else {
      codigoTipo = aprobada
        ? TipoNotificacion.BAJA_CLIENTE_APROBADA
        : TipoNotificacion.BAJA_CLIENTE_RECHAZADA;
      titulo = aprobada ? 'Baja de cliente aprobada' : 'Baja de cliente rechazada';
      mensaje = aprobada
        ? `Tu solicitud de baja de ${cliente} fue aprobada.`
        : `Tu solicitud de baja de ${cliente} fue rechazada.`;
    }

    await this.notificacionesLogic.crearYEmitir({
      idUsuario: idSolicitante,
      codigoTipo,
      titulo,
      mensaje,
      payload: {
        idBaja,
        idCliente: registro.id_cliente,
        nombreCliente: cliente,
        tipoSolicitud: registro.nombre_tipo_solicitud,
        estadoAprobacion: registro.nombre_estado_aprobacion,
      },
      idReferencia: idBaja,
      tipoReferencia: TipoReferenciaNotificacion.CLIENTE,
      claveDedupe: `${codigoTipo}:${idBaja}:${hoy}`,
      idUsuarioAuditoria,
    });
  }

  private nombreCliente(registro: Record<string, unknown>) {
    const razon = String(registro.cliente_razon_social ?? '').trim();
    if (razon) return razon;
    return (
      [registro.cliente_nombres, registro.cliente_apellido_paterno, registro.cliente_apellido_materno]
        .map((v) => String(v ?? '').trim())
        .filter(Boolean)
        .join(' ') || `Cliente #${registro.id_cliente ?? 'N/D'}`
    );
  }

  private async notificarSolicitudCliente(
    registro: Record<string, unknown>,
    dto: SolicitarBajaClienteDto | SolicitarReactivacionClienteDto,
    tipo: 'baja' | 'reactivacion',
  ) {
    const idBaja = Number(registro.id);
    const cliente = this.nombreCliente(registro);
    const solicitante = String(registro.nombre_usuario_solicita ?? 'Un usuario');
    const hoy = new Date().toISOString().slice(0, 10);
    const esBaja = tipo === 'baja';

    await this.notificacionesLogic.notificarPorPermiso({
      permiso: PermisoBanderas.BAJAS_CLIENTE_APROBAR,
      codigoTipo: esBaja
        ? TipoNotificacion.BAJA_CLIENTE_SOLICITADA
        : TipoNotificacion.REACTIVACION_CLIENTE_SOLICITADA,
      titulo: esBaja
        ? 'Solicitud de baja de cliente'
        : 'Solicitud de reactivación de cliente',
      mensaje: esBaja
        ? `${solicitante} solicitó baja del cliente ${cliente}.`
        : `${solicitante} solicitó reactivación del cliente ${cliente}.`,
      payload: {
        idBaja,
        idCliente: registro.id_cliente,
        nombreCliente: cliente,
        idUsuarioSolicita: registro.id_usuario_solicita,
        tipoSolicitud: registro.nombre_tipo_solicitud,
      },
      idReferencia: idBaja,
      tipoReferencia: TipoReferenciaNotificacion.CLIENTE,
      claveDedupePrefix: `${esBaja ? 'BAJA_CLIENTE' : 'REACTIVACION_CLIENTE'}_SOLICITADA:${idBaja}:${hoy}`,
      excluirUsuarioId: dto.idUsuarioAuditoria,
      idUsuarioAuditoria: dto.idUsuarioAuditoria,
      soloAdmins: true,
    });
  }
}
