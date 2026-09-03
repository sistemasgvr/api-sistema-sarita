import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { mapDeleteResult, mapListResult, mapSingleResult } from '../../../common/helpers/auth-response.helper';
import { FacturacionApisperuClient } from '../../../integrations/facturacion-apisperu/facturacion-apisperu.client';
import type { FacturacionApisperuDocumentResponse } from '../../../integrations/facturacion-apisperu/interfaces/facturacion-apisperu.interface';
import { FacturacionCredentialsService } from '../../../integrations/facturacion-electronica/facturacion-credentials.service';
import { TipoNotificacion, TipoReferenciaNotificacion } from '../../notificaciones/constants/tipo-notificacion';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import {
  AnularDocSalidaDto,
  ConvertirGreDto,
  CreateDocSalidaDetalleDto,
  CreateDocSalidaDto,
  CrearDesdeVentaDto,
  FiltroDocSalidaDto,
  FinalizarRecargaDto,
  GenerarRecojoDocSalidaDto,
  RegistrarDireccionEntregaDto,
  SiguienteNumeroDocSalidaQueryDto,
} from '../dto/documentos-salida.dto';
import { DocSalidaDespatchMapper } from '../mappers/doc-salida-despatch.mapper';
import { DocumentosSalidaModel } from '../models/documentos-salida.model';
import { DocSalidaPdfGenerator } from '../services/doc-salida-pdf.generator';

interface SunatResponsePayload {
  success?: boolean;
  error?: { code?: string; message?: string };
  ticket?: string;
  cdrResponse?: { accepted?: boolean; code?: string; description?: string };
}

@Injectable()
export class DocumentosSalidaLogic {
  private readonly logger = new Logger(DocumentosSalidaLogic.name);

  constructor(
    private readonly model: DocumentosSalidaModel,
    private readonly facturacionClient: FacturacionApisperuClient,
    private readonly credentialsService: FacturacionCredentialsService,
    private readonly despatchMapper: DocSalidaDespatchMapper,
    private readonly pdfGenerator: DocSalidaPdfGenerator,
    private readonly notificacionesLogic: NotificacionesLogic,
  ) {}

  async listar(filtros: FiltroDocSalidaDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtener(id: number) {
    const result = await this.model.obtener(id);
    return mapSingleResult(result, `Documento de salida ${id} no encontrado`);
  }

  async obtenerCatalogos() {
    return this.model.obtenerCatalogos();
  }

  async obtenerSiguienteNumero(query: SiguienteNumeroDocSalidaQueryDto) {
    const numero = await this.model.obtenerSiguienteNumero(query);
    return { numero };
  }

  async crear(dto: CreateDocSalidaDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el documento de salida');
  }

  async crearDesdeVenta(dto: CrearDesdeVentaDto) {
    const result = await this.model.crearDesdeVenta(dto);
    return mapSingleResult(result, 'No se pudo crear la orden de salida desde la venta');
  }

  async agregarDetalle(idDocSalida: number, dto: CreateDocSalidaDetalleDto) {
    const result = await this.model.agregarDetalle(idDocSalida, dto);
    return mapSingleResult(result, `Documento de salida ${idDocSalida} no encontrado`);
  }

  async eliminarDetalle(idDetalle: number, dto: AuditoriaDto) {
    const result = await this.model.eliminarDetalle(idDetalle, dto.idUsuarioAuditoria);
    return mapDeleteResult(result, `Línea ${idDetalle} no encontrada`);
  }

  async generar(id: number, dto: AuditoriaDto) {
    const result = await this.model.generar(id, dto.idUsuarioAuditoria);
    return mapSingleResult(result, `Documento de salida ${id} no encontrado`);
  }

  async convertirAGre(id: number, dto: ConvertirGreDto) {
    const result = await this.model.convertirAGre(id, dto);
    return mapSingleResult(result, `Documento de salida ${id} no encontrado`);
  }

  async registrarDireccionEntrega(id: number, dto: RegistrarDireccionEntregaDto) {
    const result = await this.model.registrarDireccionEntrega(id, dto);
    return mapSingleResult(result, `Documento de salida ${id} no encontrado`);
  }

  async anular(id: number, dto: AnularDocSalidaDto) {
    const result = await this.model.anular(id, dto);
    return mapSingleResult(result, `Documento de salida ${id} no encontrado`);
  }

  async finalizarRecarga(id: number, dto: FinalizarRecargaDto) {
    const result = await this.model.finalizarRecarga(id, dto);
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return this.obtener(id);
  }

  async generarRecojo(id: number, dto: GenerarRecojoDocSalidaDto) {
    const result = await this.model.generarRecojo(id, dto);
    return mapSingleResult(result, `No se pudo generar el recojo del documento ${id}`);
  }

  async generarPdf(id: number) {
    const doc = await this.model.obtener(id);

    if (doc.error) {
      throw new BadRequestException(doc.error);
    }

    if (!doc.registro) {
      throw new NotFoundException(`Documento de salida ${id} no encontrado`);
    }

    const empresa = await this.obtenerEmpresaEmisoraResuelta();
    const buffer = await this.pdfGenerator.generarA4(doc, empresa);
    const esGre = Boolean(doc.registro.serie && doc.registro.numero_sunat);
    const filename = esGre
      ? `GRE-${doc.registro.serie}-${doc.registro.numero_sunat}.pdf`
      : `OS-${doc.registro.numero}.pdf`;

    return { buffer, filename };
  }

  async emitirSunat(id: number, dto: AuditoriaDto) {
    const doc = await this.model.obtener(id);

    if (doc.error) {
      throw new BadRequestException(doc.error);
    }

    if (!doc.registro) {
      throw new NotFoundException(`Documento de salida ${id} no encontrado`);
    }

    if (doc.registro.nombre_estado_sunat === 'ACEPTADO') {
      throw new BadRequestException('El documento ya fue aceptado por SUNAT');
    }

    const ticketExistente = (doc.registro.ticket_sunat ?? '').trim();
    if (doc.registro.nombre_estado_sunat === 'PENDIENTE' && ticketExistente) {
      throw new BadRequestException(
        'El documento ya tiene ticket SUNAT pendiente. Usa «Consultar estado» antes de reemitir.',
      );
    }

    await this.assertFacturacionConfigurada({ requireGre: true });

    const empresa = await this.obtenerEmpresaEmisoraResuelta();
    const payload = this.despatchMapper.mapToDespatchPayload(doc, empresa);

    let respuesta: FacturacionApisperuDocumentResponse;
    try {
      respuesta = await this.facturacionClient.enviarGuiaRemision(payload);
    } catch (error) {
      void this.notificarEmision({
        idDoc: id,
        numero: doc.registro.numero,
        estado: 'ERROR',
        detalle: error instanceof Error ? error.message : String(error),
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      }).catch((notifyError: unknown) => {
        this.logger.warn(
          `No se pudo notificar error de emisión: ${notifyError instanceof Error ? notifyError.message : String(notifyError)}`,
        );
      });
      throw error;
    }

    const sunatResponse = (respuesta.sunatResponse ?? {}) as SunatResponsePayload;
    const estadoSunatNombre = this.resolverEstadoSunatNombre(sunatResponse);

    const actualizado = await this.model.registrarRespuestaSunat(id, {
      codigoEstadoSunat: estadoSunatNombre,
      ticketSunat: sunatResponse.ticket ?? undefined,
      hashDocumento: respuesta.hash ?? undefined,
      xmlFirmado: respuesta.xml ?? undefined,
      cdrRespuesta: JSON.stringify({ tipo: 'despatch_send', respuesta: respuesta.sunatResponse ?? respuesta }),
      idUsuarioAuditoria: dto.idUsuarioAuditoria,
    });

    if (actualizado.error) {
      throw new BadRequestException(actualizado.error);
    }

    if (estadoSunatNombre === 'RECHAZADO') {
      void this.notificarEmision({
        idDoc: id,
        numero: doc.registro.numero,
        estado: 'RECHAZADO',
        detalle: 'SUNAT rechazó el documento',
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      }).catch((notifyError: unknown) => {
        this.logger.warn(
          `No se pudo notificar rechazo: ${notifyError instanceof Error ? notifyError.message : String(notifyError)}`,
        );
      });
    }

    return {
      documento: actualizado.registro,
      sunat: {
        estado: estadoSunatNombre,
        hash: respuesta.hash ?? null,
        ticket: sunatResponse.ticket ?? null,
        respuesta: respuesta.sunatResponse ?? null,
      },
    };
  }

  async consultarEstado(id: number, dto: AuditoriaDto) {
    await this.assertFacturacionConfigurada({ requireGre: true });

    const doc = await this.model.obtener(id);

    if (doc.error) {
      throw new BadRequestException(doc.error);
    }

    if (!doc.registro) {
      throw new NotFoundException(`Documento de salida ${id} no encontrado`);
    }

    const ticket = (doc.registro.ticket_sunat ?? '').trim();
    if (!ticket) {
      throw new BadRequestException(
        'El documento no tiene ticket SUNAT. Emite primero para obtener el ticket y luego consulta el estado.',
      );
    }

    const empresa = await this.obtenerEmpresaEmisoraResuelta();
    await this.facturacionClient.asegurarCredencialesGreEnEmpresa(empresa.ruc);

    const respuesta = await this.facturacionClient.consultarEstadoGuiaRemision({ ticket });
    const estadoSunatNombre = this.resolverEstadoSunatDesdeConsulta(respuesta);

    const actualizado = await this.model.registrarRespuestaSunat(id, {
      codigoEstadoSunat: estadoSunatNombre,
      ticketSunat: ticket,
      hashDocumento: doc.registro.hash_documento ?? undefined,
      cdrRespuesta: JSON.stringify({ tipo: 'despatch_status', respuesta }),
      idUsuarioAuditoria: dto.idUsuarioAuditoria,
    });

    if (actualizado.error) {
      throw new BadRequestException(actualizado.error);
    }

    if (estadoSunatNombre === 'RECHAZADO') {
      void this.notificarEmision({
        idDoc: id,
        numero: doc.registro.numero,
        estado: 'RECHAZADO',
        detalle: 'SUNAT rechazó el documento (consulta de estado)',
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      }).catch((notifyError: unknown) => {
        this.logger.warn(
          `No se pudo notificar rechazo (consulta): ${notifyError instanceof Error ? notifyError.message : String(notifyError)}`,
        );
      });
    }

    return {
      documento: actualizado.registro,
      sunat: { estado: estadoSunatNombre, respuesta },
    };
  }

  private async notificarEmision(params: {
    idDoc: number;
    numero?: string | null;
    estado: 'RECHAZADO' | 'ERROR';
    detalle: string;
    idUsuarioAuditoria?: number;
  }) {
    const docLabel = params.numero || `Documento #${params.idDoc}`;
    const hoy = new Date().toISOString().slice(0, 10);
    const esError = params.estado === 'ERROR';
    const codigoTipo = esError ? TipoNotificacion.GUIA_ERROR_EMISION : TipoNotificacion.GUIA_SUNAT_RECHAZADA;
    const titulo = esError ? 'Error al emitir documento de salida' : 'Documento de salida rechazado por SUNAT';
    const mensaje = `${docLabel}: ${params.detalle}`;

    const byEmitir = await this.notificacionesLogic.notificarPorPermiso({
      permiso: PermisoBanderas.DOCUMENTOS_SALIDA_EMITIR,
      codigoTipo,
      titulo,
      mensaje,
      payload: { idDocSalida: params.idDoc, numero: params.numero, estado: params.estado, detalle: params.detalle },
      idReferencia: params.idDoc,
      tipoReferencia: TipoReferenciaNotificacion.GUIA_REMISION,
      claveDedupePrefix: `${codigoTipo}:${params.idDoc}:${hoy}`,
      idUsuarioAuditoria: params.idUsuarioAuditoria,
    });

    if (params.idUsuarioAuditoria && byEmitir.destinatarios === 0) {
      await this.notificacionesLogic.crearYEmitir({
        idUsuario: params.idUsuarioAuditoria,
        codigoTipo,
        titulo,
        mensaje,
        payload: { idDocSalida: params.idDoc, numero: params.numero, estado: params.estado, detalle: params.detalle },
        idReferencia: params.idDoc,
        tipoReferencia: TipoReferenciaNotificacion.GUIA_REMISION,
        claveDedupe: `${codigoTipo}:${params.idDoc}:${hoy}:${params.idUsuarioAuditoria}`,
        idUsuarioAuditoria: params.idUsuarioAuditoria,
      });
    }
  }

  private resolverEstadoSunatNombre(sunatResponse: SunatResponsePayload) {
    if (sunatResponse.success === false) return 'RECHAZADO';
    if (sunatResponse.cdrResponse?.accepted) return 'ACEPTADO';
    if (sunatResponse.ticket && !sunatResponse.cdrResponse) return 'PENDIENTE';
    if (sunatResponse.success === true) return 'ACEPTADO';
    return 'RECHAZADO';
  }

  private resolverEstadoSunatDesdeConsulta(payload: unknown) {
    const root = payload && typeof payload === 'object' ? (payload as Record<string, unknown>) : {};
    const nested =
      root.sunatResponse && typeof root.sunatResponse === 'object'
        ? (root.sunatResponse as Record<string, unknown>)
        : root;
    const cdr =
      nested.cdrResponse && typeof nested.cdrResponse === 'object'
        ? (nested.cdrResponse as Record<string, unknown>)
        : null;
    const errorObj =
      (nested.error && typeof nested.error === 'object' ? (nested.error as Record<string, unknown>) : null) ??
      (root.error && typeof root.error === 'object' ? (root.error as Record<string, unknown>) : null);

    if (nested.success === false || errorObj) return 'RECHAZADO';
    if (cdr?.accepted === true || nested.success === true) return 'ACEPTADO';

    const codeRaw = cdr?.code ?? nested.code ?? root.code;
    const code = Number(codeRaw);
    if (code === 0) return 'ACEPTADO';
    if (code === 98) return 'PENDIENTE';
    if (!Number.isNaN(code) && ((code >= 2000 && code <= 3999) || code === 99)) return 'RECHAZADO';

    return this.resolverEstadoSunatNombre(nested as SunatResponsePayload);
  }

  private async obtenerEmpresaEmisoraResuelta() {
    const creds = await this.credentialsService.resolve();
    const empresa = await this.model.obtenerEmpresaEmisora(creds.defaultRuc || undefined);

    if (!empresa) {
      throw new BadRequestException(
        'No hay empresa emisora configurada en gen_empresa (revisa RUC en Configuración → SUNAT)',
      );
    }

    return empresa;
  }

  private async assertFacturacionConfigurada(options?: { requireGre?: boolean }) {
    const status = await this.facturacionClient.getConfigStatus();

    if (!status.enabled) {
      throw new ServiceUnavailableException('La integración de facturación electrónica está deshabilitada');
    }

    if (!status.configured) {
      throw new BadRequestException('Configure token o usuario/clave del PSE en Configuración → SUNAT');
    }

    if (options?.requireGre && !status.hasGreCredentials) {
      throw new BadRequestException(
        'Configure Client ID y Client Secret OAuth GRE en Configuración → SUNAT (sección OAuth GRE)',
      );
    }
  }
}
