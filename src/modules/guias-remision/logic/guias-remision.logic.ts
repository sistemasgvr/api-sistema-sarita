import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  mapDeleteResult,
  mapListResult,
} from '../../../common/helpers/auth-response.helper';
import { FacturacionApisperuClient } from '../../../integrations/facturacion-apisperu/facturacion-apisperu.client';
import type { FacturacionApisperuDocumentResponse } from '../../../integrations/facturacion-apisperu/interfaces/facturacion-apisperu.interface';
import { FacturacionCredentialsService } from '../../../integrations/facturacion-electronica/facturacion-credentials.service';
import {
  TipoNotificacion,
  TipoReferenciaNotificacion,
} from '../../notificaciones/constants/tipo-notificacion';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import {
  CreateGuiaRemisionDto,
  FiltroGuiaRemisionDto,
  SiguienteNumeroGuiaQueryDto,
  UpdateGuiaRemisionDto,
} from '../dto/guias-remision.dto';
import { GuiaRemisionDespatchMapper } from '../mappers/guia-remision-despatch.mapper';
import { GuiasRemisionModel } from '../models/guias-remision.model';
import { GuiaRemisionPdfGenerator } from '../services/guia-remision-pdf.generator';

interface SunatResponsePayload {
  success?: boolean;
  error?: { code?: string; message?: string };
  ticket?: string;
  cdrResponse?: { accepted?: boolean; code?: string; description?: string };
}

@Injectable()
export class GuiasRemisionLogic {
  private readonly logger = new Logger(GuiasRemisionLogic.name);

  constructor(
    private readonly model: GuiasRemisionModel,
    private readonly facturacionClient: FacturacionApisperuClient,
    private readonly credentialsService: FacturacionCredentialsService,
    private readonly despatchMapper: GuiaRemisionDespatchMapper,
    private readonly pdfGenerator: GuiaRemisionPdfGenerator,
    private readonly notificacionesLogic: NotificacionesLogic,
  ) {}

  async listar(filtros: FiltroGuiaRemisionDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerCompleto(id);

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    if (!result.registro) {
      throw new NotFoundException(`Guía de remisión ${id} no encontrada`);
    }

    return {
      ...result.registro,
      detalles: result.detalles ?? [],
      referencias: result.referencias ?? [],
    };
  }

  async obtenerCatalogos() {
    return this.model.obtenerCatalogos();
  }

  async obtenerSiguienteNumero(query: SiguienteNumeroGuiaQueryDto) {
    const result = await this.model.obtenerSiguienteNumero(query);

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    return result;
  }

  async crear(dto: CreateGuiaRemisionDto) {
    const result = await this.model.crear(dto);

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    if (!result.registro) {
      throw new BadRequestException('No se pudo crear la guía de remisión');
    }

    return {
      ...result.registro,
      detalles: result.detalles ?? [],
      referencias: result.referencias ?? [],
    };
  }

  async actualizar(id: number, dto: UpdateGuiaRemisionDto) {
    const result = await this.model.actualizar(id, dto);

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    if (!result.registro) {
      throw new NotFoundException(`Guía de remisión ${id} no encontrada`);
    }

    return {
      ...result.registro,
      detalles: result.detalles ?? [],
      referencias: result.referencias ?? [],
    };
  }

  async eliminar(id: number, dto: AuditoriaDto) {
    const result = await this.model.eliminar(id, dto.idUsuarioAuditoria);
    return mapDeleteResult(
      result,
      `Guía de remisión ${id} no encontrada o ya está inactiva`,
    );
  }

  async emitir(id: number, dto: AuditoriaDto) {
    const guia = await this.model.obtenerCompleto(id);

    if (guia.error) {
      throw new BadRequestException(guia.error);
    }

    if (!guia.registro) {
      throw new NotFoundException(`Guía de remisión ${id} no encontrada`);
    }

    if (guia.registro.nombre_estado_sunat === 'ACEPTADO') {
      throw new BadRequestException('La guía ya fue aceptada por SUNAT');
    }

    const ticketExistente = (guia.registro.ticket_sunat ?? '').trim();
    if (
      guia.registro.nombre_estado_sunat === 'PENDIENTE' &&
      ticketExistente
    ) {
      throw new BadRequestException(
        'La guía ya tiene ticket SUNAT pendiente. Usa «Consultar estado» antes de reemitir.',
      );
    }

    await this.assertFacturacionConfigurada({ requireGre: true });

    const empresa = await this.obtenerEmpresaEmisoraResuelta();

    const payload = this.despatchMapper.mapToDespatchPayload(guia, empresa);
    let respuesta: FacturacionApisperuDocumentResponse;
    try {
      respuesta = await this.facturacionClient.enviarGuiaRemision(payload);
    } catch (error) {
      void this.notificarEmisionGuia({
        idGuia: id,
        serie: guia.registro.serie,
        numero: guia.registro.numero,
        estado: 'ERROR',
        detalle: error instanceof Error ? error.message : String(error),
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      }).catch((notifyError: unknown) => {
        this.logger.warn(
          `No se pudo notificar error de emisión GRE: ${
            notifyError instanceof Error ? notifyError.message : String(notifyError)
          }`,
        );
      });
      throw error;
    }

    const sunatResponse = (respuesta.sunatResponse ?? {}) as SunatResponsePayload;
    const estadoSunatNombre = this.resolverEstadoSunatNombre(sunatResponse);

    const actualizada = await this.model.registrarRespuestaSunat(id, {
      ticketSunat: sunatResponse.ticket ?? undefined,
      hashDocumento: respuesta.hash ?? undefined,
      xmlFirmado: respuesta.xml ?? undefined,
      cdrRespuesta: JSON.stringify({
        tipo: 'despatch_send',
        respuesta: respuesta.sunatResponse ?? respuesta,
      }),
      nombreEstadoSunat: estadoSunatNombre,
      idUsuarioAuditoria: dto.idUsuarioAuditoria,
    });

    if (actualizada.error) {
      throw new BadRequestException(actualizada.error);
    }

    if (estadoSunatNombre === 'RECHAZADO') {
      void this.notificarEmisionGuia({
        idGuia: id,
        serie: guia.registro.serie,
        numero: guia.registro.numero,
        estado: 'RECHAZADO',
        detalle: 'SUNAT rechazó la guía de remisión',
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      }).catch((notifyError: unknown) => {
        this.logger.warn(
          `No se pudo notificar rechazo GRE: ${
            notifyError instanceof Error ? notifyError.message : String(notifyError)
          }`,
        );
      });
    }

    return {
      guia: {
        ...actualizada.registro,
        detalles: actualizada.detalles ?? [],
        referencias: actualizada.referencias ?? [],
      },
      sunat: {
        estado: estadoSunatNombre,
        hash: respuesta.hash ?? null,
        ticket: sunatResponse.ticket ?? null,
        respuesta: respuesta.sunatResponse ?? null,
      },
    };
  }

  async generarPdf(id: number) {
    const guia = await this.model.obtenerCompleto(id);

    if (guia.error) {
      throw new BadRequestException(guia.error);
    }

    if (!guia.registro) {
      throw new NotFoundException(`Guía de remisión ${id} no encontrada`);
    }

    const empresa = await this.obtenerEmpresaEmisoraResuelta();

    const buffer = await this.pdfGenerator.generarA4(guia, empresa);
    const filename = `GRE-${guia.registro.serie}-${guia.registro.numero}.pdf`;

    return { buffer, filename };
  }

  async consultarEstado(id: number, dto: AuditoriaDto) {
    await this.assertFacturacionConfigurada({ requireGre: true });

    const guia = await this.model.obtenerCompleto(id);

    if (guia.error) {
      throw new BadRequestException(guia.error);
    }

    if (!guia.registro) {
      throw new NotFoundException(`Guía de remisión ${id} no encontrada`);
    }

    const ticket = (guia.registro.ticket_sunat ?? '').trim();
    if (!ticket) {
      throw new BadRequestException(
        'La guía no tiene ticket SUNAT. Emite primero para obtener el ticket y luego consulta el estado.',
      );
    }

    const empresa = await this.obtenerEmpresaEmisoraResuelta();
    await this.facturacionClient.asegurarCredencialesGreEnEmpresa(empresa.ruc);

    const respuesta = await this.facturacionClient.consultarEstadoGuiaRemision({
      ticket,
    });

    const estadoSunatNombre = this.resolverEstadoSunatDesdeConsulta(respuesta);

    const actualizada = await this.model.registrarRespuestaSunat(id, {
      ticketSunat: ticket,
      hashDocumento: guia.registro.hash_documento ?? undefined,
      cdrRespuesta: JSON.stringify({
        tipo: 'despatch_status',
        respuesta,
      }),
      nombreEstadoSunat: estadoSunatNombre,
      idUsuarioAuditoria: dto.idUsuarioAuditoria,
    });

    if (actualizada.error) {
      throw new BadRequestException(actualizada.error);
    }

    if (estadoSunatNombre === 'RECHAZADO') {
      void this.notificarEmisionGuia({
        idGuia: id,
        serie: guia.registro.serie,
        numero: guia.registro.numero,
        estado: 'RECHAZADO',
        detalle: 'SUNAT rechazó la guía de remisión (consulta de estado)',
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      }).catch((notifyError: unknown) => {
        this.logger.warn(
          `No se pudo notificar rechazo GRE (consulta): ${
            notifyError instanceof Error ? notifyError.message : String(notifyError)
          }`,
        );
      });
    }

    return {
      guia: {
        ...actualizada.registro,
        detalles: actualizada.detalles ?? [],
        referencias: actualizada.referencias ?? [],
      },
      sunat: {
        estado: estadoSunatNombre,
        respuesta,
      },
    };
  }

  private async notificarEmisionGuia(params: {
    idGuia: number;
    serie?: string | null;
    numero?: string | null;
    estado: 'RECHAZADO' | 'ERROR';
    detalle: string;
    idUsuarioAuditoria?: number;
  }) {
    const doc =
      [params.serie, params.numero].filter(Boolean).join('-') ||
      `Guía #${params.idGuia}`;
    const hoy = new Date().toISOString().slice(0, 10);
    const esError = params.estado === 'ERROR';
    const codigoTipo = esError
      ? TipoNotificacion.GUIA_ERROR_EMISION
      : TipoNotificacion.GUIA_SUNAT_RECHAZADA;
    const titulo = esError
      ? 'Error al emitir guía de remisión'
      : 'Guía de remisión rechazada por SUNAT';
    const mensaje = `${doc}: ${params.detalle}`;

    const byEmitir = await this.notificacionesLogic.notificarPorPermiso({
      permiso: PermisoBanderas.GUIAS_REMISION_EMITIR,
      codigoTipo,
      titulo,
      mensaje,
      payload: {
        idGuia: params.idGuia,
        serie: params.serie,
        numero: params.numero,
        estado: params.estado,
        detalle: params.detalle,
      },
      idReferencia: params.idGuia,
      tipoReferencia: TipoReferenciaNotificacion.GUIA_REMISION,
      claveDedupePrefix: `${codigoTipo}:${params.idGuia}:${hoy}`,
      idUsuarioAuditoria: params.idUsuarioAuditoria,
    });

    if (params.idUsuarioAuditoria && byEmitir.destinatarios === 0) {
      await this.notificacionesLogic.crearYEmitir({
        idUsuario: params.idUsuarioAuditoria,
        codigoTipo,
        titulo,
        mensaje,
        payload: {
          idGuia: params.idGuia,
          serie: params.serie,
          numero: params.numero,
          estado: params.estado,
          detalle: params.detalle,
        },
        idReferencia: params.idGuia,
        tipoReferencia: TipoReferenciaNotificacion.GUIA_REMISION,
        claveDedupe: `${codigoTipo}:${params.idGuia}:${hoy}:${params.idUsuarioAuditoria}`,
        idUsuarioAuditoria: params.idUsuarioAuditoria,
      });
    }
  }

  private resolverEstadoSunatNombre(sunatResponse: SunatResponsePayload) {
    if (sunatResponse.success === false) {
      return 'RECHAZADO';
    }

    if (sunatResponse.cdrResponse?.accepted) {
      return 'ACEPTADO';
    }

    if (sunatResponse.ticket && !sunatResponse.cdrResponse) {
      return 'PENDIENTE';
    }

    if (sunatResponse.success === true) {
      return 'ACEPTADO';
    }

    return 'RECHAZADO';
  }

  private resolverEstadoSunatDesdeConsulta(payload: unknown) {
    const root =
      payload && typeof payload === 'object'
        ? (payload as Record<string, unknown>)
        : {};
    const nested =
      root.sunatResponse && typeof root.sunatResponse === 'object'
        ? (root.sunatResponse as Record<string, unknown>)
        : root;
    const cdr =
      nested.cdrResponse && typeof nested.cdrResponse === 'object'
        ? (nested.cdrResponse as Record<string, unknown>)
        : null;
    const errorObj =
      (nested.error && typeof nested.error === 'object'
        ? (nested.error as Record<string, unknown>)
        : null) ??
      (root.error && typeof root.error === 'object'
        ? (root.error as Record<string, unknown>)
        : null);

    if (nested.success === false || errorObj) return 'RECHAZADO';
    if (cdr?.accepted === true || nested.success === true) return 'ACEPTADO';

    const codeRaw = cdr?.code ?? nested.code ?? root.code;
    const code = Number(codeRaw);
    if (code === 0) return 'ACEPTADO';
    if (code === 98) return 'PENDIENTE';
    if (!Number.isNaN(code) && ((code >= 2000 && code <= 3999) || code === 99)) {
      return 'RECHAZADO';
    }

    return this.resolverEstadoSunatNombre(nested as SunatResponsePayload);
  }

  private async obtenerEmpresaEmisoraResuelta() {
    const creds = await this.credentialsService.resolve();
    const empresa = await this.model.obtenerEmpresaEmisora(
      creds.defaultRuc || undefined,
    );

    if (!empresa) {
      throw new BadRequestException(
        'No hay empresa emisora configurada en gen_empresa (revisa RUC en Configuración → SUNAT)',
      );
    }

    return empresa;
  }

  private async assertFacturacionConfigurada(options?: {
    requireGre?: boolean;
  }) {
    const status = await this.facturacionClient.getConfigStatus();

    if (!status.enabled) {
      throw new ServiceUnavailableException(
        'La integración de facturación electrónica está deshabilitada',
      );
    }

    if (!status.configured) {
      throw new BadRequestException(
        'Configure token o usuario/clave del PSE en Configuración → SUNAT',
      );
    }

    if (options?.requireGre && !status.hasGreCredentials) {
      throw new BadRequestException(
        'Configure Client ID y Client Secret OAuth GRE en Configuración → SUNAT (sección OAuth GRE)',
      );
    }
  }
}
