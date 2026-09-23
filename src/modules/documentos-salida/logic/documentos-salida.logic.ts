import { pdfGreBuffer, xmlGreBuffer } from '../helpers/gre-archivos';
import { resolverEstadoGre, type GreEstado } from '../helpers/gre-estado';
import { hoyLima, normalizarPlaca, validarGre } from '../helpers/gre-validacion';
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
import type {
  FacturacionApisperuDocumentResponse,
  GreEmpresaVerificacion,
} from '../../../integrations/facturacion-apisperu/interfaces/facturacion-apisperu.interface';
import { FacturacionCredentialsService } from '../../../integrations/facturacion-electronica/facturacion-credentials.service';
import { TipoNotificacion, TipoReferenciaNotificacion } from '../../notificaciones/constants/tipo-notificacion';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import {
  ActualizarDocSalidaDetalleDto,
  ActualizarDocSalidaDto,
  AnularDocSalidaDto,
  ConvertirGreDto,
  CreateDocSalidaDetalleDto,
  CreateDocSalidaDto,
  CrearDesdeVentaDto,
  FiltroDocSalidaDto,
  FinalizarRecargaDto,
  RegistrarDireccionEntregaDto,
  SiguienteNumeroDocSalidaQueryDto,
  SeriesGreQueryDto,
  ActualizarTrasladoDto,
} from '../dto/documentos-salida.dto';
import type { DocumentoSalidaRegistro, EmpresaEmisora, GreProblema } from '../interfaces/documento-salida.interface';
import { DocSalidaDespatchMapper } from '../mappers/doc-salida-despatch.mapper';
import { DocumentosSalidaModel, type IntentoGrePendiente } from '../models/documentos-salida.model';
import { DocSalidaPdfGenerator } from '../services/doc-salida-pdf.generator';

interface SunatResponsePayload {
  success?: boolean;
  error?: { code?: string; message?: string };
  ticket?: string;
  cdrResponse?: { accepted?: boolean; code?: string; description?: string };
}

/**
 * Espera progresiva entre consultas automáticas de un ticket (minutos). Tras
 * agotar la tabla se consulta una vez al día: el ticket no se abandona, pero
 * tampoco se martilla al PSE.
 */
const ESPERA_CONSULTA_MIN = [2, 5, 15, 30, 60, 120, 240, 480];
const ESPERA_CONSULTA_MAX_MIN = 24 * 60;

export function proximaConsultaGre(consultasRealizadas: number, desde = new Date()): Date {
  const minutos = ESPERA_CONSULTA_MIN[consultasRealizadas] ?? ESPERA_CONSULTA_MAX_MIN;
  return new Date(desde.getTime() + minutos * 60_000);
}

export interface ResultadoValidacionGre {
  listo: boolean;
  entorno: string | null;
  problemas: GreProblema[];
  resumen: {
    empresa: string | null;
    ruc: string | null;
    entorno: string | null;
    tipo: string | null;
    serie: string | null;
    numero: string | null;
    fechaOrden: string | null;
    fechaEmisionGre: string | null;
    fechaTraslado: string | null;
    chofer: string | null;
    licencia: string | null;
    placa: string | null;
    transportista: string | null;
    destinatario: string | null;
    estadoEnvio: string | null;
  };
}

/**
 * Falta la empresa emisora: solo bloquea lo que va a SUNAT (emitir, consultar
 * estado, guías ya emitidas). El mensaje apunta a dónde se resuelve, porque
 * "no tiene empresa vinculada" no le decía al cajero qué hacer.
 */
const SIN_EMPRESA_EMISORA =
  'No hay una empresa configurada para la emisión electrónica. Ve a Configuración → SUNAT y registra o activa la empresa emisora.';

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

  async obtenerSiguienteNumero(query: SiguienteNumeroDocSalidaQueryDto) {
    const numero = await this.model.obtenerSiguienteNumero(query);
    return { numero };
  }

  async listarSeriesGre(query: SeriesGreQueryDto) {
    const series = await this.model.listarSeriesGre(query);
    return { series: series ?? [] };
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

  async actualizarDetalle(idDetalle: number, dto: ActualizarDocSalidaDetalleDto) {
    const result = await this.model.actualizarDetalle(idDetalle, dto);
    return mapSingleResult(result, `Línea ${idDetalle} no encontrada`);
  }

  async actualizar(id: number, dto: ActualizarDocSalidaDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Documento de salida ${id} no encontrado`);
  }

  async eliminarDetalle(idDetalle: number, dto: AuditoriaDto) {
    const result = await this.model.eliminarDetalle(idDetalle, dto.idUsuarioAuditoria);
    return mapDeleteResult(result, `Línea ${idDetalle} no encontrada`);
  }

  async actualizarTraslado(id: number, dto: ActualizarTrasladoDto) {
    const result = await this.model.actualizarTraslado(id, dto);
    return mapSingleResult(result, `Documento de salida ${id} no encontrado`);
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

  async generarPdf(id: number, idEmpresaSeleccionada?: number) {
    const doc = await this.model.obtener(id);
    if (!doc.registro) throw new NotFoundException('Documento de salida no encontrado');
    const esGuia = Boolean(doc.registro.serie || doc.registro.numero_sunat || doc.registro.ticket_sunat);
    const idEmpresa = doc.registro.id_empresa ?? (esGuia ? undefined : idEmpresaSeleccionada);
    // La guía de remisión es un documento tributario: su PDF tiene que salir con
    // el emisor real, así que sin empresa no se imprime.
    if (esGuia && !idEmpresa) throw new BadRequestException(SIN_EMPRESA_EMISORA);
    // La orden de salida, en cambio, es interna: la empresa solo alimenta el
    // membrete. Sin ella el PDF se genera igual (sin cabecera de empresa) en vez
    // de dejar al usuario sin comprobante hasta que configure SUNAT.
    if (!idEmpresa) return this.generarPdfParaEmpresa(id, null);
    return this.credentialsService.withEmpresa(idEmpresa, () => this.generarPdfParaEmpresa(id, idEmpresa));
  }

  private async generarPdfParaEmpresa(id: number, idEmpresa: number | null) {
    const doc = await this.model.obtener(id);

    if (doc.error) {
      throw new BadRequestException(doc.error);
    }

    if (!doc.registro) {
      throw new NotFoundException(`Documento de salida ${id} no encontrado`);
    }

    const esGre = Boolean(doc.registro.serie && doc.registro.numero_sunat);
    // En la orden interna una empresa inactiva o borrada tampoco frena el PDF:
    // se imprime sin membrete. En la guía sí se exige emisor válido.
    const empresa = idEmpresa
      ? esGre
        ? await this.obtenerEmpresaEmisoraResuelta(idEmpresa)
        : await this.model.obtenerEmpresaEmisora(idEmpresa)
      : null;
    const buffer = await this.pdfGenerator.generarA4(doc, empresa);
    const filename = esGre
      ? `GRE-${doc.registro.serie}-${doc.registro.numero_sunat}.pdf`
      : `OS-${doc.registro.numero}.pdf`;

    return { buffer, filename };
  }

  async emitirSunat(id: number, dto: AuditoriaDto) {
    const doc = await this.model.obtener(id);
    if (!doc.registro) throw new NotFoundException('Documento de salida no encontrado');
    const idEmpresa = doc.registro.id_empresa;
    if (!idEmpresa) throw new BadRequestException(SIN_EMPRESA_EMISORA);
    return this.credentialsService.withEmpresa(idEmpresa, () => this.emitirSunatParaEmpresa(id, dto));
  }

  private async emitirSunatParaEmpresa(id: number, dto: AuditoriaDto) {
    const doc = await this.model.obtener(id);

    if (doc.error) {
      throw new BadRequestException(doc.error);
    }

    if (!doc.registro) {
      throw new NotFoundException(`Documento de salida ${id} no encontrado`);
    }

    // Una orden anulada conserva serie y correlativo de cuando estaba vigente:
    // sin este corte se le mandaba a SUNAT una guía de un traslado que ya no
    // existe, y revertirla después exige comunicación de baja.
    if (doc.registro.nombre_estado_ciclo === 'ANULADA') {
      throw new BadRequestException(
        'El documento está anulado: no puede emitirse a SUNAT',
      );
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

    await this.assertFacturacionConfigurada();

    const empresa = await this.obtenerEmpresaEmisoraResuelta(doc.registro.id_empresa);
    // Misma prevalidación que `validar-gre`; si algo falta no se reserva intento.
    const payload = this.despatchMapper.mapToDespatchPayload(doc, empresa, { hoy: hoyLima() });

    // Solo lecturas al PSE: entorno, RUC y credenciales con los que saldría la
    // guía. La sincronización es una acción explícita de configuración.
    const verificacion = await this.facturacionClient.verificarEmpresaGre(empresa.ruc);
    if (!verificacion.listo) {
      throw new BadRequestException(
        `La empresa ${empresa.ruc} no está lista para emitir GRE: ${verificacion.problemas.join('; ')}`,
      );
    }

    // El intento queda registrado (con empresa y entorno) antes de contactar
    // al proveedor: un doble clic o una segunda pestaña chocan con el índice
    // único de intentos abiertos y no generan un segundo envío.
    const intentoId = await this.model.iniciarIntentoGre(
      id,
      doc.registro,
      payload,
      {
        idEmpresa: empresa.id,
        rucEmisor: empresa.ruc,
        entorno: verificacion.entorno,
        idEmpresaPse: verificacion.companyId,
      },
      dto.idUsuarioAuditoria,
    );
    let respuesta: FacturacionApisperuDocumentResponse;
    try {
      respuesta = await this.facturacionClient.enviarGuiaRemision(payload, verificacion);
    } catch (error) {
      // No guardar credenciales ni mensajes crudos del proveedor en el historial.
      await this.model.guardarResultadoIntentoGre(intentoId, 'POR_CONFIRMAR', { error: 'No se pudo confirmar la respuesta del proveedor' });
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
    const estadoSunatNombre = resolverEstadoGre(sunatResponse);
    // El intento se cierra antes de tocar el documento: así lo que devuelve
    // doc_registrar_respuesta_sunat (gre_estado_envio) ya es el estado final.
    await this.model.guardarResultadoIntentoGre(
      intentoId,
      estadoSunatNombre,
      respuesta,
      estadoSunatNombre === 'PENDIENTE' ? proximaConsultaGre(0) : null,
    );

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

    // Con ticket PENDIENTE, SUNAT suele resolverlo en segundos: se consulta de
    // una vez para no dejar al usuario esperando el próximo tick del cron (que
    // recién revisa tickets nuevos a partir de los 2 minutos). Si la consulta
    // inmediata falla, la emisión ya quedó guardada y el cron la retoma.
    if (estadoSunatNombre === 'PENDIENTE') {
      try {
        return await this.consultarEstadoParaEmpresa(id, dto);
      } catch (error) {
        this.logger.warn(
          `No se pudo consultar el estado inmediato del ticket recién emitido (doc ${id}): ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    }

    return {
      documento: actualizado.registro,
      sunat: {
        estado: estadoSunatNombre,
        entorno: verificacion.entorno,
        hash: respuesta.hash ?? null,
        ticket: sunatResponse.ticket ?? null,
        respuesta: respuesta.sunatResponse ?? null,
      },
    };
  }

  /**
   * Prevalidación estructurada (misma que corre la emisión) más la
   * verificación del PSE. No escribe nada: sirve para mostrar «Lista para
   * emitir» o los problemas junto al campo.
   */
  async validarGre(id: number): Promise<ResultadoValidacionGre> {
    const doc = await this.model.obtener(id);
    if (doc.error) throw new BadRequestException(doc.error);
    if (!doc.registro) throw new NotFoundException(`Documento de salida ${id} no encontrado`);
    const cabecera = doc.registro;

    const empresa = cabecera.id_empresa ? await this.model.obtenerEmpresaEmisora(cabecera.id_empresa) : null;
    const problemas = validarGre(cabecera, empresa, { hoy: hoyLima() });

    if (cabecera.nombre_estado_ciclo === 'ANULADA') {
      problemas.push({ codigo: 'ANULADA', campo: 'estado', mensaje: 'El documento está anulado', severidad: 'error' });
    }
    if (cabecera.nombre_estado_sunat === 'ACEPTADO') {
      problemas.push({ codigo: 'YA_ACEPTADA', campo: 'estado', mensaje: 'La guía ya fue aceptada por SUNAT', severidad: 'error' });
    }
    if ((cabecera.ticket_sunat ?? '').trim() && cabecera.nombre_estado_sunat === 'PENDIENTE') {
      problemas.push({
        codigo: 'TICKET_PENDIENTE',
        campo: 'estado',
        mensaje: 'La guía ya tiene ticket SUNAT pendiente; consulta su estado en lugar de reemitir',
        severidad: 'error',
      });
    }
    if (cabecera.gre_estado_envio && !['RECHAZADO'].includes(cabecera.gre_estado_envio) && cabecera.nombre_estado_sunat !== 'ACEPTADO') {
      if (cabecera.gre_estado_envio === 'POR_CONFIRMAR') {
        problemas.push({
          codigo: 'POR_CONFIRMAR',
          campo: 'estado',
          mensaje: 'Hay un envío con resultado por confirmar; concílialo antes de volver a emitir',
          severidad: 'error',
        });
      }
    }

    let verificacion: GreEmpresaVerificacion | null = null;
    if (empresa) {
      try {
        verificacion = await this.credentialsService.withEmpresa(empresa.id, () =>
          this.facturacionClient.verificarEmpresaGre(empresa.ruc),
        );
        for (const mensaje of verificacion.problemas) {
          problemas.push({ codigo: 'PSE', campo: 'configuracion', mensaje, severidad: 'error' });
        }
      } catch (error) {
        problemas.push({
          codigo: 'PSE_NO_DISPONIBLE',
          campo: 'configuracion',
          mensaje: `No se pudo verificar la empresa en el PSE: ${error instanceof Error ? error.message : String(error)}`,
          severidad: 'error',
        });
      }
    }

    const entorno = verificacion?.entorno ?? cabecera.gre_entorno ?? null;
    return {
      listo: problemas.every((p) => p.severidad !== 'error'),
      entorno,
      problemas,
      resumen: this.resumenGre(cabecera, empresa, entorno),
    };
  }

  private resumenGre(cabecera: DocumentoSalidaRegistro, empresa: EmpresaEmisora | null, entorno: string | null) {
    const flotaPropia = cabecera.codigo_tipo_guia === '31' || (cabecera.codigo_modalidad_traslado ?? '02') === '02';
    return {
      empresa: empresa?.razon_social ?? empresa?.nombre_comercial ?? null,
      ruc: empresa?.ruc ?? null,
      entorno,
      tipo: cabecera.codigo_tipo_guia,
      serie: cabecera.serie,
      numero: cabecera.numero_sunat,
      fechaOrden: cabecera.fecha?.slice(0, 10) ?? null,
      fechaEmisionGre: cabecera.fecha_emision_gre?.slice(0, 10) ?? null,
      fechaTraslado: cabecera.fecha_traslado?.slice(0, 10) ?? null,
      chofer: flotaPropia ? cabecera.nombre_chofer : null,
      licencia: flotaPropia ? cabecera.licencia_chofer : null,
      placa: flotaPropia ? normalizarPlaca(cabecera.placa_vehiculo) || null : null,
      transportista: flotaPropia ? null : cabecera.nombre_transportista,
      destinatario: cabecera.nombre_destinatario ?? cabecera.nombre_cliente ?? cabecera.nombre_proveedor ?? null,
      estadoEnvio: cabecera.gre_estado_envio ?? null,
    };
  }

  async historialGre(id: number) {
    const doc = await this.model.obtener(id);
    if (!doc.registro) throw new NotFoundException('Documento de salida no encontrado');
    return { intentos: await this.model.listarHistorialGre(id) };
  }

  async consultarEstado(id: number, dto: AuditoriaDto) {
    const doc = await this.model.obtener(id);
    if (!doc.registro) throw new NotFoundException('Documento de salida no encontrado');
    const idEmpresa = doc.registro.id_empresa;
    if (!idEmpresa) throw new BadRequestException(SIN_EMPRESA_EMISORA);
    return this.credentialsService.withEmpresa(idEmpresa, () => this.consultarEstadoParaEmpresa(id, dto));
  }

  /**
   * Consulta automática de tickets pendientes con espera progresiva. La llama
   * el cron del API y el job HTTP; cada ticket se consulta con la empresa y
   * el entorno de su intento, nunca con una configuración ajena.
   */
  async consultarPendientes(limite = 20) {
    const pendientes = await this.model.listarIntentosGrePendientesConsulta(limite);
    const resultado = { consultados: 0, aceptados: 0, rechazados: 0, pendientes: 0, errores: 0 };
    for (const intento of pendientes) {
      try {
        const r = await this.consultarIntentoPendiente(intento);
        resultado.consultados += 1;
        if (r === 'ACEPTADO') resultado.aceptados += 1;
        else if (r === 'RECHAZADO') resultado.rechazados += 1;
        else resultado.pendientes += 1;
      } catch (error) {
        // Error técnico (PSE caído, entorno cambiado): no es rechazo fiscal.
        // Se reprograma y se conserva el ticket.
        resultado.errores += 1;
        await this.model.programarConsultaGre(intento.id, proximaConsultaGre(intento.consultas));
        this.logger.warn(
          `Consulta automática GRE doc ${intento.id_doc_salida} falló: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    }
    return resultado;
  }

  private async consultarIntentoPendiente(intento: IntentoGrePendiente): Promise<GreEstado> {
    if (!intento.id_empresa) throw new BadRequestException('Intento sin empresa emisora');
    const r = await this.credentialsService.withEmpresa(intento.id_empresa, () =>
      this.consultarEstadoParaEmpresa(intento.id_doc_salida, {}),
    );
    return r.sunat.estado;
  }

  private async consultarEstadoParaEmpresa(id: number, dto: AuditoriaDto) {
    await this.assertFacturacionConfigurada();

    const doc = await this.model.obtener(id);

    if (doc.error) {
      throw new BadRequestException(doc.error);
    }

    if (!doc.registro) {
      throw new NotFoundException(`Documento de salida ${id} no encontrado`);
    }

    if (doc.registro.nombre_estado_ciclo === 'ANULADA') {
      throw new BadRequestException(
        'El documento está anulado; no se consulta estado SUNAT.',
      );
    }

    const ticket = (doc.registro.ticket_sunat ?? '').trim();
    if (!ticket) {
      throw new BadRequestException(
        'El documento no tiene ticket SUNAT. Emite primero para obtener el ticket y luego consulta el estado.',
      );
    }

    // Un ticket se consulta en el entorno donde se emitió. Si la empresa
    // cambió de entorno en el PSE, el resultado no sería el de esa guía.
    const intento = await this.model.obtenerUltimoIntentoGre(id);
    if (intento?.entorno) {
      const empresa = await this.obtenerEmpresaEmisoraResuelta(doc.registro.id_empresa);
      const verificacion = await this.facturacionClient.verificarEmpresaGre(empresa.ruc);
      if (verificacion.entorno && verificacion.entorno !== intento.entorno) {
        throw new BadRequestException(
          `La guía se envió en entorno ${intento.entorno.toUpperCase()} y la empresa está ahora en ${verificacion.entorno.toUpperCase()} en el PSE. ` +
            'Vuelve a ese entorno para consultar el ticket; el resultado queda por confirmar.',
        );
      }
    }

    const respuesta = await this.facturacionClient.consultarEstadoGuiaRemision({ ticket });
    const estadoSunatNombre = resolverEstadoGre(respuesta);

    // Primero el historial del intento; luego el documento (que ya devuelve
    // el estado de envío actualizado).
    await this.model.registrarConsultaGre(
      id,
      estadoSunatNombre,
      respuesta,
      estadoSunatNombre === 'PENDIENTE' ? proximaConsultaGre((intento?.consultas ?? 0) + 1) : null,
    );

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
      sunat: { estado: estadoSunatNombre, entorno: intento?.entorno ?? null, respuesta },
    };
  }

  /** Compatibilidad con el botón anterior; no emite ni vuelve a firmar XML. */
  async descargarPdfXmlOficiales(id: number) {
    const results = await Promise.allSettled([this.obtenerPdfOficial(id), this.obtenerXmlOficial(id)]);
    const pdfDescargado = results[0].status === 'fulfilled' && Boolean(results[0].value);
    const xmlDescargado = results[1].status === 'fulfilled' && Boolean(results[1].value);
    if (!pdfDescargado && !xmlDescargado) {
      throw new BadRequestException('No hay archivos disponibles del envío. Abre PDF o XML para ver el motivo.');
    }
    return {
      pdfDescargado, xmlDescargado,
      mensaje: `PDF: ${pdfDescargado ? 'disponible' : 'no disponible'}. XML del envío: ${xmlDescargado ? 'disponible' : 'no disponible'}.`,
    };
  }

  async obtenerPdfOficial(id: number): Promise<{ buffer: Buffer; filename: string }> {
    const doc = await this.model.obtener(id);
    if (!doc.registro) throw new NotFoundException('Documento de salida no encontrado');
    const fuente = await this.model.obtenerFuenteArchivosGre(id);
    if (!fuente || !fuente.id_empresa) {
      throw new BadRequestException('Esta guía histórica no tiene los datos originales del envío. Puedes visualizar su PDF local.');
    }
    if (fuente.id_empresa !== doc.registro.id_empresa) {
      throw new BadRequestException('La empresa del envío no coincide con la guía');
    }
    let pdf = fuente.pdf_base64;
    if (!pdf) {
      pdf = await this.credentialsService.withEmpresa(fuente.id_empresa, async () => {
        const company = fuente.solicitud.company as { ruc?: string } | undefined;
        if (!company?.ruc) throw new BadRequestException('El envío no conserva el RUC del emisor');
        const verificacion = await this.facturacionClient.verificarEmpresaGre(company.ruc);
        if (!fuente.entorno || verificacion.entorno !== fuente.entorno) {
          throw new BadRequestException('El entorno del proveedor no coincide con el entorno del envío original');
        }
        return this.facturacionClient.despatchPdf(fuente.solicitud);
      });
      if (!pdf) throw new BadRequestException('El proveedor no pudo generar el PDF. Intenta nuevamente.');
      pdfGreBuffer(pdf);
      await this.model.guardarPdfGre(fuente.id, pdf);
    }
    return { buffer: pdfGreBuffer(pdf), filename: `GRE-${doc.registro.serie}-${doc.registro.numero_sunat}.pdf` };
  }

  async obtenerXmlOficial(id: number): Promise<{ buffer: Buffer; filename: string }> {
    const doc = await this.model.obtener(id);
    if (!doc.registro) throw new NotFoundException('Documento de salida no encontrado');
    const fuente = await this.model.obtenerFuenteArchivosGre(id);
    // Con intento, no usar un XML residual de un envío anterior.
    const original = fuente ? fuente.respuesta?.xml : await this.model.obtenerXmlHistoricoGre(id);
    const buffer = xmlGreBuffer(original);
    if (!buffer) throw new NotFoundException('El proveedor aún no ha entregado el XML de este envío');
    return { buffer, filename: `GRE-${doc.registro.serie}-${doc.registro.numero_sunat}.xml` };
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

  private async obtenerEmpresaEmisoraResuelta(idEmpresa: number | null) {
    if (!idEmpresa) throw new BadRequestException(SIN_EMPRESA_EMISORA);
    const empresa = await this.model.obtenerEmpresaEmisora(idEmpresa);
    if (!empresa)
      throw new BadRequestException(
        'La empresa emisora de la guía está inactiva. Actívala en Configuración → SUNAT para emitir o consultar.',
      );
    return empresa;
  }

  /**
   * Acceso al PSE (token o usuario/clave). Las credenciales OAuth GRE ya no se
   * exigen aquí: en BETA no hacen falta las reales y en producción las revisa
   * `verificarEmpresaGre` contra el entorno efectivo de la empresa.
   */
  private async assertFacturacionConfigurada() {
    const status = await this.facturacionClient.getConfigStatus();

    if (!status.enabled) {
      throw new ServiceUnavailableException('La integración de facturación electrónica está deshabilitada');
    }

    if (!status.configured) {
      throw new BadRequestException('Configure token o usuario/clave del PSE en Configuración → SUNAT');
    }
  }
}
