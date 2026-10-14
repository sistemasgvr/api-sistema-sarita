import { estadoDesdeCdr, cdrCorrespondeAlDocumento, esErrorEnvioCpe } from '../../../common/helpers/cpe-estado.helper';
import { SunatValidezClient } from '../../../integrations/facturacion-electronica/sunat-validez.client';
import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { FacturacionApisperuClient } from '../../../integrations/facturacion-apisperu/facturacion-apisperu.client';
import type { FacturacionApisperuDocumentResponse } from '../../../integrations/facturacion-apisperu/interfaces/facturacion-apisperu.interface';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ClientesModel } from '../../clientes/models/clientes.model';
import {
  TipoNotificacion,
  TipoReferenciaNotificacion,
} from '../../notificaciones/constants/tipo-notificacion';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  AnularComprobanteDto,
  ConvertirTipoComprobanteDto,
  CreateComprobantesDto,
  EnviarResumenDiarioDto,
  FiltroComprobantesDto,
  FiltroResumenDiarioDto,
  RegistrarCobroComprobanteDto,
  RegistrarRespuestaSunatDto,
  SiguienteNumeroQueryDto,
  UpdateComprobantesDto,
} from '../dto/comprobantes.dto';
import { ComprobanteInvoiceMapper } from '../mappers/comprobante-invoice.mapper';
import { ComprobantesModel } from '../models/comprobantes.model';
import type { SiguienteNumeroResult } from '../models/comprobantes.model';
import { ComprobanteNotaVentaPdfGenerator } from '../services/comprobante-nota-venta-pdf.generator';
import { ComprobanteTicketPdfGenerator } from '../services/comprobante-ticket-pdf.generator';

const CODIGO_VENTA_SIN_DOC = 'VSD';
const CODIGO_NOTA_VENTA_LEGACY = 'NV';

function esCodigoVentaSinDocumento(codigo?: string | null): boolean {
  const value = (codigo ?? '').trim().toUpperCase();
  return value === CODIGO_VENTA_SIN_DOC || value === CODIGO_NOTA_VENTA_LEGACY;
}

function documentoEsRuc(cliente: {
  nombre_tipo_documento?: string | null;
  numero_documento?: string | null;
}): boolean {
  const tipo = (cliente.nombre_tipo_documento ?? '').toUpperCase();
  const doc = (cliente.numero_documento ?? '').trim();
  if (tipo.includes('RUC')) return /^\d{11}$/.test(doc);
  return /^\d{11}$/.test(doc);
}

/** Plazo máximo de emisión SUNAT (días calendario desde la fecha del comprobante). */
function diasPlazoEmisionSunat(codigoTipo?: string | null): number | null {
  if (codigoTipo === '01') return 3;
  if (codigoTipo === '03') return 5;
  return null;
}

function diasDesdeFechaComprobante(fecha: string | Date): number {
  const raw =
    typeof fecha === 'string'
      ? fecha.slice(0, 10)
      : fecha.toISOString().slice(0, 10);
  const [y, m, d] = raw.split('-').map(Number);
  const inicio = Date.UTC(y, m - 1, d);
  const ahora = new Date();
  const hoy = Date.UTC(ahora.getFullYear(), ahora.getMonth(), ahora.getDate());
  return Math.floor((hoy - inicio) / 86_400_000);
}

export interface SunatResponsePayload {
  success?: boolean;
  error?: { code?: string; message?: string };
  ticket?: string;
  cdrResponse?: { accepted?: boolean; code?: string; description?: string };
}

@Injectable()
export class ComprobantesLogic {
  private readonly logger = new Logger(ComprobantesLogic.name);

  constructor(
    private readonly model: ComprobantesModel,
    private readonly clientesModel: ClientesModel,
    private readonly facturacionClient: FacturacionApisperuClient,
    private readonly invoiceMapper: ComprobanteInvoiceMapper,
    private readonly ticketPdfGenerator: ComprobanteTicketPdfGenerator,
    private readonly notaVentaPdfGenerator: ComprobanteNotaVentaPdfGenerator,
    private readonly notificacionesLogic: NotificacionesLogic,
    private readonly validezClient: SunatValidezClient,
  ) {}

  async consultarValidez(id: number) {
    const comprobante = await this.model.obtenerCompleto(id);
    if (comprobante.error) throw new BadRequestException(comprobante.error);
    const doc = comprobante.registro;
    if (!doc) throw new NotFoundException('Comprobante no encontrado');
    if (!['01', '03'].includes(doc.codigo_tipo_comprobante ?? '')) {
      throw new BadRequestException('La consulta de validez está disponible para facturas y boletas.');
    }
    const empresa = await this.model.obtenerEmpresaEmisora();
    if (!empresa) throw new BadRequestException('Empresa emisora no configurada');
    return this.validezClient.consultar(empresa.id, {
      tipo: doc.codigo_tipo_comprobante!, serie: doc.serie, numero: doc.numero,
      fecha: doc.fecha_emision_cpe ?? doc.fecha, total: Number(doc.total_importe),
    });
  }

  async listar(filtros: FiltroComprobantesDto) {
    const result = await this.model.listar(filtros);
    const rows = (result.registros ?? []) as Array<{ id: number; serie?: string; numero?: string; nombre_estado_sunat?: string; estado_cdr_registrado?: string; advertencia_cdr?: string; reintento_permitido?: boolean; fecha_emision_cpe?: string | null; estado_envio?: 'EN_CURSO' | 'POR_CONFIRMAR' | 'ERROR_ENVIO' }>;
    const evidencias = await this.model.evidenciasCdr(rows.map(row => row.id));
    for (const row of rows) {
      const evidencia = evidencias.find(item => item.id === row.id);
      row.fecha_emision_cpe = evidencia?.fecha_emision_cpe ?? null;
      // La confirmación exacta de SUNAT prevalece sobre el envío aún esperando al PSE.
      if (evidencia?.validez_aceptada && row.nombre_estado_sunat === 'ACEPTADO') continue;
      if (evidencia?.emision_en_curso) row.estado_envio = 'EN_CURSO';
      const raw = evidencia?.cdr_respuesta;
      if (!raw) continue;
      try {
        const payload = JSON.parse(raw);
        if (!evidencia?.emision_en_curso && row.nombre_estado_sunat === 'PENDIENTE' && esErrorEnvioCpe(payload)) {
          row.estado_envio='ERROR_ENVIO';
          const v=evidencia?.cpe_verificacion;
          row.reintento_permitido=v?.reintentoPermitido===true && v.serie===row.serie && v.numero===row.numero &&
            Date.now()-Date.parse(v.verificadoEn)<300000;
        }
        if (!evidencia?.emision_en_curso && row.estado_envio!=='ERROR_ENVIO' && payload.tipo === 'emision_por_confirmar') row.estado_envio = 'POR_CONFIRMAR';
        const cdr = (payload.sunatResponse ?? payload).cdrResponse;
        if (!evidencia?.emision_en_curso && row.nombre_estado_sunat === 'PENDIENTE' && estadoDesdeCdr(payload) === 'ACEPTADO') {
          row.estado_envio = 'POR_CONFIRMAR';
        }
        if (cdr && estadoDesdeCdr(payload) === 'RECHAZADO') {
          row.estado_cdr_registrado = 'RECHAZADO';
          row.advertencia_cdr = 'Respuesta guardada del envío anterior (' + cdr.code + '). ' + (String(cdr.code) === '2325'
            ? 'SUNAT indicó que el certificado no estaba comunicado al procesar ese envío. Su registro posterior no modifica este CDR. Consulta la validez para comprobar la situación actual.'
            : 'El CDR de ese envío indicó rechazo. Consulta la validez y el detalle del comprobante.');
        }
      } catch { /* No inferir estados a partir de respuestas ilegibles. */ }
    }
    return mapListResult(result, filtros);
  }

  async sincronizarValidez(id: number, usuario: number) {
    const validez = await this.consultarValidez(id);
    const actualizado = validez.codigo === '1'
      ? await this.model.sincronizarValidez(id, validez, usuario) : false;
    return { ...validez, soloLectura: !actualizado, estadoActualizado: actualizado };
  }

  /** Comprueba el envío; nunca emite, renumera ni cambia los pagos de la venta. */
  async verificarEnvio(id: number, usuario?: number) {
    const { registro: doc } = await this.model.obtenerCompleto(id);
    if (!doc) throw new NotFoundException('Comprobante no encontrado');
    if (!['01','03'].includes(doc.codigo_tipo_comprobante ?? '')) throw new BadRequestException('Verificación disponible para facturas y boletas');
    const activo = (await this.model.evidenciasCdr([id]))[0]?.emision_en_curso ?? false;
    let estado = activo ? 'EN_CURSO' : 'SIN_CONFIRMACION';
    const verificadoEn = new Date().toISOString();
    let codigoValidez: string | null = null;
    let codigoCdr: string | null = null;
    let codigoProveedor: string | null = null;
    let rechazo: string | null = null;
    try {
      const validez = await this.consultarValidez(id);
      codigoValidez = validez.codigo;
      if (validez.codigo === '1' && await this.model.sincronizarValidez(id,validez,usuario ?? null)) estado='ACEPTADO';
    } catch { /* Ausencia de respuesta no equivale a rechazo. */ }
    if (estado !== 'ACEPTADO' && !activo) {
      try {
        const emisor = await this.model.obtenerEmpresaEmisora();
        if (!emisor) throw new Error('Emisor no configurado');
        const lock=await this.model.reclamarOperacionCpe(emisor.id);
        if (!lock) throw new Error('Otra operación del proveedor está activa');
        let respuesta: Record<string, any>;
        try { respuesta = await this.facturacionClient.consultarEstadoFacturaBoleta({
          ruc:emisor.ruc, tipo:doc.codigo_tipo_comprobante!, serie:doc.serie, numero:String(Number(doc.numero)),
        }); } finally { await this.model.liberarOperacionCpe(emisor.id,lock); }
        const sunat = respuesta.sunatResponse ?? respuesta as SunatResponsePayload;
        codigoCdr = String((sunat as SunatResponsePayload).cdrResponse?.code ?? '') || null;
        codigoProveedor=String((sunat as SunatResponsePayload).error?.code ?? '') || null;
        if (codigoCdr && estadoDesdeCdr(respuesta)==='RECHAZADO' && cdrCorrespondeAlDocumento(respuesta,doc.serie,doc.numero,doc.fecha_emision_cpe??doc.fecha,codigoCdr)) {
          estado='RECHAZADO';
          rechazo=JSON.stringify(respuesta);
        }
      } catch { /* Se seguirá verificando; ninguna respuesta incierta autoriza reenvío. */ }
    }
    let errorExplicito=false;
    try { errorExplicito=esErrorEnvioCpe(JSON.parse(doc.cdr_respuesta ?? '{}')); } catch {}
    const reintentoPermitido=!activo && estado==='SIN_CONFIRMACION' && errorExplicito && codigoValidez==='0' && codigoProveedor==='0127' && !doc.ticket_sunat;
    if (estado==='SIN_CONFIRMACION' && errorExplicito) estado='ERROR_ENVIO';
    const evidencia = { estado, verificadoEn, codigoValidez, codigoCdr, codigoProveedor, reintentoPermitido, serie:doc.serie, numero:doc.numero };
    if (!await this.model.guardarVerificacion(id,doc,evidencia,rechazo,usuario)) {
      throw new BadRequestException('El comprobante cambió durante la verificación. Consulta nuevamente su referencia actual.');
    }
    // Respeta una aceptación o baja guardada concurrentemente.
    const actual = (await this.model.obtenerCompleto(id)).registro;
    if (['ACEPTADO','BAJA'].includes(actual?.nombre_estado_sunat ?? '')) estado=actual!.nombre_estado_sunat!;
    return { ...evidencia, estado, mensaje: estado==='ACEPTADO' ? (codigoValidez==='1' ? 'SUNAT confirmó la aceptación del comprobante.' : 'El estado guardado es Aceptado; esta verificación no obtuvo una nueva confirmación.')
      : estado==='RECHAZADO' ? 'El CDR de este comprobante confirma rechazo. Revisa el motivo antes de reintentar.'
      : estado==='ERROR_ENVIO' ? (reintentoPermitido ? 'El proveedor devolvió un error de envío. SUNAT y la consulta de CDR no encuentran el comprobante; puedes reintentar con la misma serie y número.' : 'El proveedor devolvió un error de envío. Verifica nuevamente antes de reintentar.')
      : estado==='EN_CURSO' ? 'La solicitud de emisión sigue activa.'
      : 'El envío aún no tiene un resultado definitivo. Se seguirá verificando automáticamente; no se ha reenviado.' };
  }

  async obtenerXml(id: number) {
    const comprobante = await this.obtenerPorId(id);
    const original = comprobante.xml_firmado;
    if (!original?.trim()) {
      throw new NotFoundException('Este comprobante no tiene XML firmado guardado');
    }
    const buffer = original.trimStart().startsWith('<')
      ? Buffer.from(original, 'utf8')
      : Buffer.from(original.trim(), 'base64');
    if (!buffer.toString('utf8').replace(/^\uFEFF/, '').trimStart().startsWith('<')) {
      throw new BadRequestException('El XML guardado del comprobante no es válido');
    }
    const filename = `${comprobante.serie}-${comprobante.numero}.xml`.replace(/[^a-zA-Z0-9_.-]/g, '_');
    return { buffer, filename };
  }

  async obtenerPorId(id: number) {
    // Incluye las percepciones vinculadas (solo lectura).
    const result = await this.model.obtenerPorId(id);

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    if (!result.registro) {
      throw new NotFoundException(`Comprobante ${id} no encontrado`);
    }

    return {
      ...result.registro,
      detalles: result.detalles ?? [],
      cuotas: result.cuotas ?? [],
      // Fase 3: sin esto el desglose del cobro se perdía aquí, porque este
      // return arma la respuesta campo a campo en vez de propagar el resultado.
      pagos: result.pagos ?? [],
      // El préstamo de cilindros y la garantía no son líneas de la venta: viven
      // en bal_prestamo y ven_garantia, y ven_obtener_comprobante los trae por
      // JOIN para que el detalle muestre la operación completa.
      prestamos: result.prestamos ?? [],
      garantias: result.garantias ?? [],
    };
  }

  async previewResumenDiario(fecha: string) {
    const items = await this.model.listarParaResumenDiario(fecha);
    const yaInformados = await this.model.existeResumenDiarioInformado(fecha);
    const total = items.reduce(
      (acc, item) => acc + Number(item.total_importe ?? 0),
      0,
    );

    return {
      fecha,
      cantidad: items.length,
      total,
      items,
      yaInformados,
    };
  }

  async listarResumenDiario(filtros: FiltroResumenDiarioDto) {
    const result = await this.model.listarResumenDiario(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerResumenDiario(id: number) {
    const result = await this.model.obtenerResumenDiario(id);

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    if (!result.registro) {
      throw new NotFoundException(`Resumen diario ${id} no encontrado`);
    }

    return {
      ...result.registro,
      detalles: result.detalles ?? [],
    };
  }

  async obtenerSiguienteCorrelativoResumen(fecha: string) {
    return this.model.obtenerSiguienteCorrelativoResumen(fecha);
  }

  async enviarResumenDiario(dto: EnviarResumenDiarioDto) {
    await this.assertFacturacionConfigurada();

    const items = await this.model.listarParaResumenDiario(
      dto.fecha,
      dto.idsComprobante,
    );

    if (!items.length) {
      throw new BadRequestException(
        'No hay boletas ni notas de crédito (serie B) para resumir en la fecha indicada',
      );
    }

    const empresa = await this.model.obtenerEmpresaEmisora();

    if (!empresa) {
      throw new BadRequestException(
        'No hay empresa emisora configurada en gen_empresa',
      );
    }

    const totalImporte = items.reduce(
      (acc, item) => acc + Number(item.total_importe ?? 0),
      0,
    );
    const totalIgv = items.reduce(
      (acc, item) => acc + Number(item.igv ?? 0),
      0,
    );
    const totalValorVenta = items.reduce(
      (acc, item) => acc + Number(item.valor_venta ?? 0),
      0,
    );

    const claim = await this.model.reclamarResumenLock(dto.fecha);
    if (!claim.ok) {
      throw new BadRequestException(
        claim.error ?? 'No se pudo reservar el correlativo del resumen diario',
      );
    }

    let correlativo = dto.correlativo?.trim();
    let resumenCreado: Awaited<
      ReturnType<ComprobantesModel['crearResumenDiario']>
    > | null = null;

    try {
      if (!correlativo) {
        const siguiente = await this.model.obtenerSiguienteCorrelativoResumen(
          dto.fecha,
        );
        correlativo = siguiente.correlativo || '001';
      }

      // Persistir primero: si SUNAT responde OK pero falla el INSERT local,
      // el correlativo/ticket se perdían y se podía reenviar el mismo lote.
      resumenCreado = await this.model.crearResumenDiario({
        fecha: dto.fecha,
        correlativo,
        ticketSunat: null,
        idEstadoSunat: null,
        cdrRespuesta: null,
        moneda: items[0]?.codigo_moneda ?? 'PEN',
        cantidadDocs: items.length,
        totalImporte,
        totalIgv,
        totalValorVenta,
        idsComprobante: items.map((item) => item.id),
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      });
    } finally {
      await this.model.liberarResumenLock(claim);
    }

    if (!resumenCreado || resumenCreado.error || !resumenCreado.registro) {
      throw new BadRequestException(
        resumenCreado?.error ??
          'No se pudo registrar el historial del resumen diario',
      );
    }

    const payload = this.invoiceMapper.mapComprobantesToSummaryPayload(
      items,
      empresa,
      dto.fecha,
      correlativo,
    );

    let respuesta: {
      sunatResponse?: SunatResponsePayload;
      hash?: string;
    };
    try {
      respuesta = await this.facturacionClient.enviarResumenDiario(payload);
    } catch (error) {
      this.logger.warn(
        `Resumen diario #${resumenCreado.registro.id} quedó local sin ticket SUNAT: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      throw error;
    }

    const sunatResponse = (respuesta.sunatResponse ??
      {}) as SunatResponsePayload;
    const estadoSunatNombre = this.resolverEstadoSunatNombre(sunatResponse);
    const idEstadoSunat =
      await this.model.resolverIdEstadoSunat(estadoSunatNombre);
    const ticket = sunatResponse.ticket ?? null;

    const resumenActualizado = await this.model.registrarRespuestaResumenDiario(
      resumenCreado.registro.id,
      {
        idEstadoSunat,
        ticketSunat: ticket,
        cdrRespuesta: JSON.stringify(respuesta.sunatResponse ?? respuesta),
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      },
    );

    if (resumenActualizado.error || !resumenActualizado.registro) {
      throw new BadRequestException(
        resumenActualizado.error ??
          'El resumen se envió a SUNAT pero no se pudo guardar la respuesta',
      );
    }

    for (const item of items) {
      await this.model.registrarRespuestaSunat(item.id, {
        idEstadoSunat: idEstadoSunat ?? undefined,
        ticketSunat: ticket ?? undefined,
        cdrRespuesta: JSON.stringify({
          tipo: 'resumen_diario',
          id_resumen: resumenActualizado.registro.id,
          fecha: dto.fecha,
          correlativo,
          resumen: respuesta.sunatResponse ?? respuesta,
        }),
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      });
    }

    return {
      resumen: {
        ...resumenActualizado.registro,
        detalles: resumenActualizado.detalles ?? resumenCreado.detalles ?? [],
      },
      fecha: dto.fecha,
      correlativo,
      cantidad: items.length,
      items,
      sunat: {
        estado: estadoSunatNombre,
        ticket,
        respuesta: respuesta.sunatResponse ?? null,
      },
    };
  }

  async consultarEstadoResumenPorId(id: number, dto: AuditoriaDto) {
    await this.assertFacturacionConfigurada();

    const resumen = await this.model.obtenerResumenDiario(id);

    if (resumen.error) {
      throw new BadRequestException(resumen.error);
    }

    if (!resumen.registro) {
      throw new NotFoundException(`Resumen diario ${id} no encontrado`);
    }

    const ticket = resumen.registro.ticket_sunat?.trim();

    if (!ticket) {
      throw new BadRequestException(
        'El resumen aún no tiene ticket SUNAT para consultar',
      );
    }

    const respuesta = await this.facturacionClient.consultarEstadoResumen({
      ticket,
    });
    const sunatResponse = respuesta as SunatResponsePayload;
    const estadoSunatNombre = this.resolverEstadoSunatDesdeConsulta(respuesta);
    const idEstadoSunat =
      await this.model.resolverIdEstadoSunat(estadoSunatNombre);

    const actualizado = await this.model.registrarRespuestaResumenDiario(id, {
      idEstadoSunat,
      ticketSunat: ticket,
      cdrRespuesta: JSON.stringify(respuesta),
      idUsuarioAuditoria: dto.idUsuarioAuditoria,
    });

    if (actualizado.error || !actualizado.registro) {
      throw new BadRequestException(
        actualizado.error ?? 'No se pudo actualizar el estado del resumen',
      );
    }

    if (estadoSunatNombre === 'ACEPTADO' || estadoSunatNombre === 'RECHAZADO') {
      for (const detalle of actualizado.detalles ?? []) {
        await this.model.registrarRespuestaSunat(detalle.id_comprobante, {
          idEstadoSunat: idEstadoSunat ?? undefined,
          ticketSunat: ticket,
          cdrRespuesta: JSON.stringify({
            tipo: 'resumen_diario',
            id_resumen: id,
            resumen: respuesta,
          }),
          idUsuarioAuditoria: dto.idUsuarioAuditoria,
        });
      }
    }

    return {
      resumen: {
        ...actualizado.registro,
        detalles: actualizado.detalles ?? [],
      },
      sunat: {
        estado: estadoSunatNombre,
        ticket,
        respuesta,
      },
    };
  }

  async consultarEstadoResumen(ticket: string) {
    await this.assertFacturacionConfigurada();

    if (!ticket.trim()) {
      throw new BadRequestException('El ticket del resumen es obligatorio');
    }

    const respuesta = await this.facturacionClient.consultarEstadoResumen({
      ticket: ticket.trim(),
    });

    return {
      ticket: ticket.trim(),
      sunat: {
        estado: this.resolverEstadoSunatDesdeConsulta(respuesta),
        respuesta,
      },
    };
  }

  async obtenerSiguienteNumero(
    query: SiguienteNumeroQueryDto,
  ): Promise<SiguienteNumeroResult> {
    const result = await this.model.obtenerSiguienteNumero(query);

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    return result;
  }

  async crear(dto: CreateComprobantesDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el comprobante');
  }

  async actualizar(id: number, dto: UpdateComprobantesDto) {
    const doc=(await this.model.obtenerCompleto(id)).registro;
    if (this.parseCdrMeta(doc?.cdr_respuesta)?.tipo==='emision_por_confirmar') {
      throw new BadRequestException('El comprobante tiene un envío en revisión. Conserva sus datos y utiliza Verificar envío o Reintentar envío.');
    }
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Comprobante ${id} no encontrado`);
  }

  /**
   * Boleta ↔ factura en el mismo comprobante (no elimina ni recrea): stock,
   * cilindros, CxC, cobros y orden de salida siguen ligados al mismo id. La
   * función SQL valida que SUNAT no tenga el documento y asigna el siguiente
   * correlativo de la serie destino.
   */
  async regularizar(id: number, usuario: number) {
    const doc = (await this.model.obtenerCompleto(id)).registro;
    if (!doc || !['01','03'].includes(doc.codigo_tipo_comprobante ?? '')) throw new BadRequestException('Solo se regularizan facturas o boletas existentes.');
    const serie = doc.codigo_tipo_comprobante === '01' ? 'F002' : 'B002';
    if (doc.serie === serie) throw new BadRequestException('Este comprobante ya usa la serie nueva; consulta su validez o intenta su emisión cuando corresponda.');
    const activo = (await this.model.evidenciasCdr([id]))[0]?.emision_en_curso;
    if (activo) throw new BadRequestException('La emisión está en curso; espera su resultado antes de regularizar.');
    const validez = await this.consultarValidez(id);
    if (validez.codigo !== '0') throw new BadRequestException('SUNAT respondió ' + validez.estado + '. No se cambió el comprobante.');
    const empresa = await this.model.obtenerEmpresaEmisora();
    const siguiente = await this.model.obtenerSiguienteNumero({ idTipoComprobante: doc.id_tipo_comprobante, serie });
    if (!siguiente.numero) throw new BadRequestException('No se pudo obtener la numeración de la serie nueva.');
    const existente = await this.facturacionClient.consultarEstadoFacturaBoleta({ ruc: empresa!.ruc, tipo: doc.codigo_tipo_comprobante!, serie, numero: String(Number(siguiente.numero)) });
    const consultaSerie = (existente.sunatResponse ?? existente) as Record<string, any>;
    if (String(consultaSerie.code ?? consultaSerie.error?.code) !== '0127') throw new BadRequestException('No se confirmó que la referencia fiscal nueva esté disponible en SUNAT. No se regularizó.');
    const parts = new Intl.DateTimeFormat('en-CA', {timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());
    const part = (key: string) => parts.find(p => p.type === key)!.value;
    const fecha = part('year') + '-' + part('month') + '-' + part('day');
    return mapSingleResult(await this.model.regularizar(id, serie, fecha, validez, doc.cdr_respuesta ?? null, siguiente.numero, usuario), 'Comprobante no encontrado');
  }

  async historialCpe(id: number) {
    return (await this.model.historialCpe(id)).rows;
  }

  async notasFiscalesCorreccion(id: number) {
    mapSingleResult(await this.model.obtenerCompleto(id),'Comprobante no encontrado');
    return (await this.model.notasFiscalesCorreccion(id)).rows;
  }

  async pdfNotaFiscalCorreccion(id: number, idNota: number) {
    const nota=(await this.model.notaFiscalCorreccion(id,idNota)).rows[0];
    if (!nota) throw new NotFoundException('Nota fiscal no encontrada para este comprobante');
    if (nota.estado!=='ACEPTADO') throw new BadRequestException('La nota aún no tiene aceptación confirmada');
    return this.facturacionClient.generarPdfNota(nota.payload);
  }

  async convertirTipo(id: number, dto: ConvertirTipoComprobanteDto) {
    const result = await this.model.convertirTipo(id, dto);
    return mapSingleResult(result, `Comprobante ${id} no encontrado`);
  }

  async registrarCobro(id: number, dto: RegistrarCobroComprobanteDto) {
    const result = await this.model.registrarCobro(id, dto);
    return mapSingleResult(result, `Comprobante ${id} no encontrado`);
  }

  /**
   * El usuario respondió que la venta no es para envío: cierra la custodia de
   * los cilindros en el acto, porque sin orden de salida no habrá reparto que
   * los saque de la reserva PENDIENTE_ENVIO.
   */
  async confirmarEntregaMostrador(id: number, dto: AuditoriaDto) {
    const result = await this.model.confirmarEntregaMostrador(
      id,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Comprobante ${id} no encontrado`);
  }

  async eliminar(id: number, dto: AuditoriaDto) {
    const result = await this.model.eliminar(id, dto.idUsuarioAuditoria);
    return mapDeleteResult(result, `Comprobante ${id} no encontrado`);
  }

  async registrarRespuestaSunat(id: number, dto: RegistrarRespuestaSunatDto) {
    const result = await this.model.registrarRespuestaSunat(id, dto);
    return mapSingleResult(result, `Comprobante ${id} no encontrado`);
  }

  async consultarCdr(id: number, dto: AuditoriaDto) {
    await this.assertFacturacionConfigurada();

    const comprobante = await this.model.obtenerCompleto(id);

    if (comprobante.error) {
      throw new BadRequestException(comprobante.error);
    }

    if (!comprobante.registro) {
      throw new NotFoundException(`Comprobante ${id} no encontrado`);
    }



    const cdrMeta = this.parseCdrMeta(comprobante.registro.cdr_respuesta);
    const ticketBaja = (comprobante.registro.ticket_sunat ?? '').trim();
    const esBajaPendiente =
      cdrMeta?.tipo === 'comunicacion_baja' && Boolean(ticketBaja);

    if (esBajaPendiente) {
      return this.consultarEstadoBaja(id, ticketBaja, dto, comprobante);
    }

    const tipo = comprobante.registro.codigo_tipo_comprobante;
    const serie = comprobante.registro.serie;
    const numero = comprobante.registro.numero;

    if (!tipo || !serie || !numero) {
      throw new BadRequestException(
        'El comprobante no tiene tipo, serie o número',
      );
    }

    if (['01', '03'].includes(tipo)) {
      const validez = await this.consultarValidez(id);
      if (validez.codigo !== '1') {
        throw new BadRequestException('SUNAT no confirma la aceptación para la fecha e importe de este comprobante. Usa Consultar validez; no se actualizó el CDR ni el estado.');
      }
    }

    const respuesta = await this.facturacionClient.consultarEstadoFacturaBoleta(
      {
        tipo,
        serie,
        numero: numero.replace(/^0+/, '') || '0',
      },
    );

    if (['01', '03'].includes(tipo) && !cdrCorrespondeAlDocumento(respuesta, serie, numero, (comprobante.registro.fecha_emision_cpe ?? comprobante.registro.fecha))) {
      throw new BadRequestException('El CDR consultado no corresponde a la referencia y fecha del comprobante actual. No se actualizó el documento.');
    }

    const sunatResponse = (respuesta.sunatResponse ??
      respuesta) as SunatResponsePayload;
    const estadoSunatNombre = this.resolverEstadoSunatNombre(sunatResponse);
    const idEstadoSunat =
      await this.model.resolverIdEstadoSunat(estadoSunatNombre);

    const comprobanteActualizado = await this.model.registrarRespuestaSunat(
      id,
      {
        idEstadoSunat: idEstadoSunat ?? undefined,
        ticketSunat:
          sunatResponse.ticket ??
          comprobante.registro.ticket_sunat ??
          undefined,
        hashDocumento: comprobante.registro.hash_documento ?? undefined,
        cdrRespuesta: JSON.stringify(respuesta),
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      },
    );

    if (comprobanteActualizado.error) {
      throw new BadRequestException(comprobanteActualizado.error);
    }

    if (estadoSunatNombre === 'RECHAZADO') {
      if (tipo === '07') {
        const revertido = await this.model.revertirNcSunatRechazada(
          id,
          dto.idUsuarioAuditoria,
        );
        if (revertido?.error) {
          throw new BadRequestException(revertido.error);
        }
      }

      void this.notificarEmisionComprobante({
        idComprobante: id,
        serie: comprobante.registro.serie,
        numero: comprobante.registro.numero,
        codigoTipo: tipo,
        estado: 'RECHAZADO',
        detalle: 'SUNAT rechazó el comprobante (consulta CDR)',
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      }).catch((notifyError: unknown) => {
        this.logger.warn(
          `No se pudo notificar rechazo CDR: ${
            notifyError instanceof Error ? notifyError.message : String(notifyError)
          }`,
        );
      });
    }

    return {
      comprobante: comprobanteActualizado.registro,
      sunat: {
        estado: estadoSunatNombre,
        ticket: sunatResponse.ticket ?? null,
        respuesta,
      },
    };
  }

  /**
   * Consulta ticket de comunicación de baja (voided/status).
   * Si SUNAT acepta, marca BAJA y revierte efectos (stock/CxC).
   */
  private async consultarEstadoBaja(
    id: number,
    ticket: string,
    dto: AuditoriaDto,
    comprobante: Awaited<ReturnType<ComprobantesModel['obtenerCompleto']>>,
  ) {
    const respuesta =
      await this.facturacionClient.consultarEstadoComunicacionBaja({
        ticket,
      });
    const sunatResponse = (respuesta.sunatResponse ??
      respuesta) as SunatResponsePayload;
    const estadoSunatNombre =
      this.resolverEstadoBajaNombre(sunatResponse) ??
      this.resolverEstadoSunatDesdeConsulta(respuesta);
    const idEstadoSunat = await this.model.resolverIdEstadoSunat(
      estadoSunatNombre === 'ACEPTADO' ? 'BAJA' : estadoSunatNombre,
    );

    const comprobanteActualizado = await this.model.registrarRespuestaSunat(
      id,
      {
        idEstadoSunat: idEstadoSunat ?? undefined,
        ticketSunat: ticket,
        hashDocumento: comprobante.registro?.hash_documento ?? undefined,
        cdrRespuesta: JSON.stringify({
          tipo: 'comunicacion_baja',
          ticket,
          voided: respuesta.sunatResponse ?? respuesta,
        }),
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      },
    );

    if (comprobanteActualizado.error) {
      throw new BadRequestException(comprobanteActualizado.error);
    }

    if (estadoSunatNombre === 'ACEPTADO') {
      const revertido = await this.model.revertirEfectos(
        id,
        dto.idUsuarioAuditoria,
      );
      if (revertido?.error) {
        throw new BadRequestException(revertido.error);
      }
    }

    return {
      comprobante: comprobanteActualizado.registro,
      sunat: {
        estado: estadoSunatNombre === 'ACEPTADO' ? 'BAJA' : estadoSunatNombre,
        ticket,
        respuesta,
      },
    };
  }

  private parseCdrMeta(cdrRespuesta?: string | null): { tipo?: string } | null {
    if (!cdrRespuesta?.trim()) return null;
    try {
      const parsed = JSON.parse(cdrRespuesta) as { tipo?: string };
      return parsed && typeof parsed === 'object' ? parsed : null;
    } catch {
      return null;
    }
  }

  async anular(id: number, dto: AnularComprobanteDto) {
    await this.assertFacturacionConfigurada();

    const motivo = dto.motivo?.trim();

    if (!motivo) {
      throw new BadRequestException('Debe indicar el motivo de la baja');
    }

    const comprobante = await this.model.obtenerCompleto(id);

    if (comprobante.error) {
      throw new BadRequestException(comprobante.error);
    }

    if (!comprobante.registro) {
      throw new NotFoundException(`Comprobante ${id} no encontrado`);
    }

    if (comprobante.registro.nombre_estado_sunat === 'BAJA') {
      throw new BadRequestException('El comprobante ya está dado de baja');
    }

    if (comprobante.registro.nombre_estado_sunat !== 'ACEPTADO') {
      throw new BadRequestException(
        'Solo se pueden anular comprobantes aceptados por SUNAT. Si aún no se emitió, elimínelo.',
      );
    }

    const tipoDoc = comprobante.registro.codigo_tipo_comprobante;

    if (tipoDoc === '03') {
      throw new BadRequestException(
        'Las boletas no se anulan con comunicación de baja. Emita una nota de crédito.',
      );
    }

    const empresa = await this.model.obtenerEmpresaEmisora();

    if (!empresa) {
      throw new BadRequestException(
        'No hay empresa emisora configurada en gen_empresa',
      );
    }

    const payload = this.invoiceMapper.mapComprobanteToVoidedPayload(
      comprobante,
      empresa,
      motivo,
    );

    const respuesta =
      await this.facturacionClient.enviarComunicacionBaja(payload);
    const sunatResponse = (respuesta.sunatResponse ??
      {}) as SunatResponsePayload;
    const estadoSunatNombre =
      this.resolverEstadoBajaNombre(sunatResponse) ??
      (sunatResponse.ticket ? 'PENDIENTE' : 'RECHAZADO');
    const idEstadoSunat = await this.model.resolverIdEstadoSunat(
      estadoSunatNombre === 'ACEPTADO' ? 'BAJA' : estadoSunatNombre,
    );

    const comprobanteActualizado = await this.model.registrarRespuestaSunat(
      id,
      {
        idEstadoSunat: idEstadoSunat ?? undefined,
        ticketSunat: sunatResponse.ticket ?? undefined,
        hashDocumento:
          respuesta.hash ?? comprobante.registro.hash_documento ?? undefined,
        cdrRespuesta: JSON.stringify({
          tipo: 'comunicacion_baja',
          motivo,
          voided: respuesta.sunatResponse ?? respuesta,
        }),
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      },
    );

    if (comprobanteActualizado.error) {
      throw new BadRequestException(comprobanteActualizado.error);
    }

    if (estadoSunatNombre === 'ACEPTADO') {
      const revertido = await this.model.revertirEfectos(id, dto.idUsuarioAuditoria);
      if (revertido?.error) {
        throw new BadRequestException(revertido.error);
      }
    }

    return {
      comprobante: comprobanteActualizado.registro,
      sunat: {
        estado: estadoSunatNombre === 'ACEPTADO' ? 'BAJA' : estadoSunatNombre,
        hash: respuesta.hash ?? null,
        ticket: sunatResponse.ticket ?? null,
        respuesta: respuesta.sunatResponse ?? null,
        ...(estadoSunatNombre === 'PENDIENTE' && sunatResponse.ticket
          ? {
              mensaje:
                'Baja en proceso (ticket). Consulte CDR del comprobante para confirmar y revertir efectos.',
            }
          : {}),
      },
    };
  }

  async emitir(id: number, dto: AuditoriaDto, reintento = false) {
    const claim = await this.model.reclamarEmision(id);
    if (!claim.ok) {
      throw new BadRequestException(
        claim.error ?? 'No se pudo reclamar la emisión del comprobante',
      );
    }

    let operacion: {idEmpresa:number;token:string} | null=null;
    try {
      const comprobante = await this.model.obtenerCompleto(id);

      if (comprobante.error) {
        throw new BadRequestException(comprobante.error);
      }

      if (!comprobante.registro) {
        throw new NotFoundException(`Comprobante ${id} no encontrado`);
      }

      await this.assertFacturacionConfigurada();
      const empresa = await this.model.obtenerEmpresaEmisora();
      if (!empresa) throw new BadRequestException('No hay empresa emisora configurada');
      const token=await this.model.reclamarOperacionCpe(empresa.id);
      if (!token) throw new BadRequestException('Hay otra operación de emisión activa para esta empresa. Espera a que termine; este comprobante no se ha enviado.');
      operacion={idEmpresa:empresa.id,token};

      if (comprobante.registro.nombre_estado_sunat === 'ACEPTADO') {
        throw new BadRequestException('El comprobante ya fue aceptado por SUNAT');
      }

      if (comprobante.registro.nombre_estado_sunat === 'BAJA') {
        throw new BadRequestException('El comprobante está dado de baja');
      }
      if (reintento && !esErrorEnvioCpe(this.parseCdrMeta(comprobante.registro.cdr_respuesta))) {
        throw new BadRequestException('Este intento no tiene un fallo explícito de envío verificable. No se reenvió el comprobante.');
      }

      if (this.parseCdrMeta(comprobante.registro.cdr_respuesta)?.tipo === 'emision_por_confirmar') {
        const validez = await this.consultarValidez(id);
        if (validez.codigo === '1') {
          await this.model.sincronizarValidez(id,validez,dto.idUsuarioAuditoria ?? null);
        }
        const errorExplicito=esErrorEnvioCpe(this.parseCdrMeta(comprobante.registro.cdr_respuesta));
        if (!reintento || !errorExplicito || validez.codigo!=='0' || comprobante.registro.ticket_sunat) {
          throw new BadRequestException('El envío anterior aún requiere revisión: SUNAT respondió ' + validez.estado + '. Usa Verificar envío para obtener una respuesta definitiva antes de reintentar. No se volvió a emitir.');
        }
      }

      const plazoDias = diasPlazoEmisionSunat(
        comprobante.registro.codigo_tipo_comprobante,
      );
      if (plazoDias != null && comprobante.registro.fecha) {
        const transcurridos = diasDesdeFechaComprobante(
          comprobante.registro.fecha_emision_cpe ?? comprobante.registro.fecha,
        );
        if (transcurridos > plazoDias) {
          const tipoLabel =
            comprobante.registro.codigo_tipo_comprobante === '01'
              ? 'factura'
              : 'boleta';
          throw new BadRequestException(
            `No se puede emitir: la ${tipoLabel} supera el plazo de ${plazoDias} días desde su fecha`,
          );
        }
      }

      if (!empresa) {
        throw new BadRequestException(
          'No hay empresa emisora configurada en gen_empresa',
        );
      }

      const clienteResult = await this.clientesModel.obtenerPorId(
        comprobante.registro.id_cliente,
      );

      if (!clienteResult.registro) {
        throw new BadRequestException('El cliente del comprobante no existe');
      }

      if (
        esCodigoVentaSinDocumento(
          comprobante.registro.codigo_tipo_comprobante_origen,
        ) &&
        !clienteResult.registro.numero_documento?.trim()
      ) {
        clienteResult.registro.numero_documento = '00000000';
      }

      this.assertDocumentoClienteParaEmitir(
        comprobante.registro.codigo_tipo_comprobante,
        comprobante.registro.serie,
        clienteResult.registro,
      );

      const ubigeo = clienteResult.registro.id_distrito
        ? await this.model.obtenerCodigoUbigeoDistrito(
            clienteResult.registro.id_distrito,
          )
        : '';

      const payload = this.invoiceMapper.mapComprobanteToInvoicePayload(
        comprobante,
        empresa,
        clienteResult.registro,
        ubigeo,
      );

      const tipoDoc = comprobante.registro.codigo_tipo_comprobante;
      let respuesta: FacturacionApisperuDocumentResponse;

      if (['01', '03'].includes(tipoDoc ?? '')) {
        const existente = await this.facturacionClient.consultarEstadoFacturaBoleta({
          ruc: empresa.ruc,
          tipo: tipoDoc!,
          serie: comprobante.registro.serie,
          numero: comprobante.registro.numero.replace(/^0+/, '') || '0',
        });
        if (estadoDesdeCdr(existente) === 'ACEPTADO') {
          throw new BadRequestException(
            'SUNAT ya devuelve una constancia aceptada para esta serie y correlativo. Puede corresponder a un documento anterior: no se envió esta venta. Revisa el historial de numeración y usa una referencia fiscal nueva cuando corresponda.',
          );
        }
        if (reintento) {
          const status=(existente.sunatResponse ?? existente) as SunatResponsePayload;
          if (String(status.error?.code ?? '')!=='0127' || status.cdrResponse || status.ticket) {
            throw new BadRequestException('El proveedor no confirma que esta referencia carezca de CDR. No se reintentó el envío.');
          }
        }
      }

      try {
        if (tipoDoc === '07' || tipoDoc === '08') {
          respuesta = await this.facturacionClient.enviarNota(payload);
        } else {
          // Deja constancia antes de salir al proveedor: un reinicio del API
          // tampoco debe perder la verificación de una emisión incierta.
          const pendiente = await this.model.resolverIdEstadoSunat('PENDIENTE');
          const inicio = await this.model.registrarRespuestaSunat(id, {
            idEstadoSunat: pendiente ?? undefined,
            cdrRespuesta: JSON.stringify({ tipo:'emision_por_confirmar', fase:'ENVIANDO', fecha:new Date().toISOString() }),
            idUsuarioAuditoria:dto.idUsuarioAuditoria,
          },reintento);
          if (inicio.error) throw new BadRequestException(inicio.error);
          if (inicio.registro?.nombre_estado_sunat === 'ACEPTADO') return {
            comprobante:inicio.registro, sunat:{estado:'ACEPTADO',hash:null,ticket:null,respuesta:null},
          };
          respuesta = await this.facturacionClient.enviarFacturaBoleta(payload);
        }
      } catch (error) {
        if (/tiempo de espera|timeout|timed out|por confirmar|no se pudo comunicar/i.test(error instanceof Error ? error.message : '')) {
          const pendiente = await this.model.resolverIdEstadoSunat('PENDIENTE');
          const guardado = await this.model.registrarRespuestaSunat(id, {
            idEstadoSunat: pendiente ?? undefined,
            cdrRespuesta: JSON.stringify({ tipo: 'emision_por_confirmar', fase:'SIN_RESPUESTA', motivo: 'El proveedor no confirmó el resultado del envío', fecha: new Date().toISOString() }),
            idUsuarioAuditoria: dto.idUsuarioAuditoria,
          },reintento);
          if (guardado.error) this.logger.warn('No se pudo registrar el envío por confirmar del comprobante ' + id);
          if (guardado.registro?.nombre_estado_sunat === 'ACEPTADO') {
            return { comprobante: guardado.registro,
              sunat: { estado: 'ACEPTADO', hash: null, ticket: null, respuesta: null } };
          }
        }
        void this.notificarEmisionComprobante({
          idComprobante: id,
          serie: comprobante.registro.serie,
          numero: comprobante.registro.numero,
          codigoTipo: tipoDoc,
          estado: 'ERROR',
          detalle: error instanceof Error ? error.message : String(error),
          idUsuarioAuditoria: dto.idUsuarioAuditoria,
        }).catch((notifyError: unknown) => {
          this.logger.warn(
            `No se pudo notificar error de emisión: ${
              notifyError instanceof Error ? notifyError.message : String(notifyError)
            }`,
          );
        });
        throw error;
      }

      const sunatResponse = (respuesta.sunatResponse ??
        {}) as SunatResponsePayload;
      let estadoSunatNombre = this.resolverEstadoSunatNombre(sunatResponse);
      if (['01', '03'].includes(tipoDoc ?? '') && estadoSunatNombre === 'ACEPTADO' &&
          !cdrCorrespondeAlDocumento(respuesta, comprobante.registro.serie, comprobante.registro.numero, comprobante.registro.fecha_emision_cpe ?? comprobante.registro.fecha)) {
        estadoSunatNombre = 'PENDIENTE';
      }
      const idEstadoSunat =
        await this.model.resolverIdEstadoSunat(estadoSunatNombre);

      const comprobanteActualizado = await this.model.registrarRespuestaSunat(
        id,
        {
          idEstadoSunat: idEstadoSunat ?? undefined,
          ticketSunat: sunatResponse.ticket ?? undefined,
          hashDocumento: respuesta.hash ?? undefined,
          xmlFirmado: respuesta.xml ?? undefined,
          cdrRespuesta: JSON.stringify(estadoSunatNombre === 'PENDIENTE'
            ? { tipo: 'emision_por_confirmar', fase:'SIN_RESPUESTA', sunatResponse: respuesta.sunatResponse ?? respuesta }
            : respuesta.sunatResponse ?? respuesta),
          idUsuarioAuditoria: dto.idUsuarioAuditoria,
        },
        reintento,
      );

      if (comprobanteActualizado.error) {
        throw new BadRequestException(comprobanteActualizado.error);
      }

      if (comprobanteActualizado.registro?.nombre_estado_sunat === 'ACEPTADO') estadoSunatNombre = 'ACEPTADO';
      if (estadoSunatNombre === 'RECHAZADO') {
        // NC aplica stock/CxC al crear. Si SUNAT rechaza, revertir + soft-delete
        // para no inflar inventario y liberar el tope de cantidades.
        if (tipoDoc === '07') {
          const revertido = await this.model.revertirNcSunatRechazada(
            id,
            dto.idUsuarioAuditoria,
          );
          if (revertido?.error) {
            this.logger.warn(
              `NC #${id} rechazada por SUNAT pero no se pudo revertir/eliminar: ${revertido.error}`,
            );
          }
        }

        void this.notificarEmisionComprobante({
          idComprobante: id,
          serie: comprobante.registro.serie,
          numero: comprobante.registro.numero,
          codigoTipo: tipoDoc,
          estado: 'RECHAZADO',
          detalle: 'SUNAT rechazó el comprobante',
          idUsuarioAuditoria: dto.idUsuarioAuditoria,
        }).catch((notifyError: unknown) => {
          this.logger.warn(
            `No se pudo notificar rechazo SUNAT: ${
              notifyError instanceof Error ? notifyError.message : String(notifyError)
            }`,
          );
        });
      }

      return {
        comprobante: comprobanteActualizado.registro,
        sunat: {
          estado: estadoSunatNombre === 'PENDIENTE' && esErrorEnvioCpe(respuesta) ? 'ERROR_ENVIO' : estadoSunatNombre,
          hash: respuesta.hash ?? null,
          ticket: sunatResponse.ticket ?? null,
          respuesta: respuesta.sunatResponse ?? null,
        },
      };
    } finally {
      try { if (operacion) await this.model.liberarOperacionCpe(operacion.idEmpresa,operacion.token); }
      finally { await this.model.liberarEmisionLock(id, claim.client); }
    }
  }

  /** Valida documento del cliente vs tipo CPE (igual que FE). */
  private assertDocumentoClienteParaEmitir(
    codigoTipo: string | null | undefined,
    serie: string | null | undefined,
    cliente: {
      nombre_tipo_documento?: string | null;
      numero_documento?: string | null;
    },
  ) {
    const codigo = (codigoTipo ?? '').trim();
    if (!['01', '03', '07', '08'].includes(codigo)) {
      return;
    }

    const doc = (cliente.numero_documento ?? '').trim();
    if (!doc) {
      throw new BadRequestException(
        'El cliente no tiene documento. Asigna DNI/RUC al cliente antes de emitir',
      );
    }

    const requiereRuc =
      codigo === '01' ||
      ((codigo === '07' || codigo === '08') &&
        (serie ?? '').trim().toUpperCase().startsWith('F'));

    if (requiereRuc && !documentoEsRuc(cliente)) {
      throw new BadRequestException(
        codigo === '01'
          ? 'La factura requiere un cliente con RUC (11 dígitos)'
          : 'Este comprobante (serie F) requiere un cliente con RUC (11 dígitos)',
      );
    }
  }

  private async notificarEmisionComprobante(params: {
    idComprobante: number;
    serie?: string | null;
    numero?: string | null;
    codigoTipo?: string | null;
    estado: 'RECHAZADO' | 'ERROR';
    detalle: string;
    idUsuarioAuditoria?: number;
  }) {
    const doc =
      [params.serie, params.numero].filter(Boolean).join('-') ||
      `Comprobante #${params.idComprobante}`;
    const hoy = new Date().toISOString().slice(0, 10);
    const esError = params.estado === 'ERROR';
    const codigoTipo = esError
      ? TipoNotificacion.COMPROBANTE_ERROR_EMISION
      : TipoNotificacion.COMPROBANTE_SUNAT_RECHAZADO;
    const titulo = esError
      ? 'Error al emitir comprobante'
      : 'Comprobante rechazado por SUNAT';
    const mensaje = `${doc}: ${params.detalle}`;

    const byEmitir = await this.notificacionesLogic.notificarPorPermiso({
      permiso: PermisoBanderas.COMPROBANTES_EMITIR,
      codigoTipo,
      titulo,
      mensaje,
      payload: {
        idComprobante: params.idComprobante,
        serie: params.serie,
        numero: params.numero,
        codigoTipoComprobante: params.codigoTipo,
        estado: params.estado,
        detalle: params.detalle,
      },
      idReferencia: params.idComprobante,
      tipoReferencia: TipoReferenciaNotificacion.COMPROBANTE,
      claveDedupePrefix: `${codigoTipo}:${params.idComprobante}:${hoy}`,
      idUsuarioAuditoria: params.idUsuarioAuditoria,
    });

    // Fallback: avisar al emisor si nadie con permiso emitir recibió la notif
    if (params.idUsuarioAuditoria && byEmitir.destinatarios === 0) {
      await this.notificacionesLogic.crearYEmitir({
        idUsuario: params.idUsuarioAuditoria,
        codigoTipo,
        titulo,
        mensaje,
        payload: {
          idComprobante: params.idComprobante,
          serie: params.serie,
          numero: params.numero,
          estado: params.estado,
          detalle: params.detalle,
        },
        idReferencia: params.idComprobante,
        tipoReferencia: TipoReferenciaNotificacion.COMPROBANTE,
        claveDedupe: `${codigoTipo}:${params.idComprobante}:${hoy}:${params.idUsuarioAuditoria}`,
        idUsuarioAuditoria: params.idUsuarioAuditoria,
      });
    }
  }

  async generarPdf(id: number, formato: 'a4' | 'ticket' = 'a4') {
    const comprobante = await this.model.obtenerCompleto(id);

    if (comprobante.error) {
      throw new BadRequestException(comprobante.error);
    }

    if (!comprobante.registro) {
      throw new NotFoundException(`Comprobante ${id} no encontrado`);
    }

    const esNotaVenta = esCodigoVentaSinDocumento(
      comprobante.registro.codigo_tipo_comprobante,
    );

    if (!esNotaVenta) {
      await this.assertFacturacionConfigurada();
    }

    const empresa = await this.model.obtenerEmpresaEmisora();

    if (!empresa) {
      throw new BadRequestException(
        'No hay empresa emisora configurada en gen_empresa',
      );
    }

    const clienteResult = await this.clientesModel.obtenerPorId(
      comprobante.registro.id_cliente,
    );

    if (!clienteResult.registro) {
      throw new BadRequestException('El cliente del comprobante no existe');
    }

    let pdfBuffer: Buffer;

    if (esNotaVenta) {
      let logoBase64: string | null = null;
      try {
        logoBase64 = await this.facturacionClient.obtenerLogoEmpresaBase64(
          empresa.ruc,
        );
      } catch {
        logoBase64 = null;
      }

      if (formato === 'ticket') {
        pdfBuffer = await this.ticketPdfGenerator.generar(
          comprobante,
          empresa,
          clienteResult.registro,
          { documentoInterno: true, logoBase64 },
        );
      } else {
        pdfBuffer = await this.notaVentaPdfGenerator.generarA4(
          comprobante,
          empresa,
          clienteResult.registro,
          logoBase64,
        );
      }
    } else {
      const ubigeo = clienteResult.registro.id_distrito
        ? await this.model.obtenerCodigoUbigeoDistrito(
            clienteResult.registro.id_distrito,
          )
        : '';

      if (formato === 'ticket') {
        pdfBuffer = await this.ticketPdfGenerator.generar(
          comprobante,
          empresa,
          clienteResult.registro,
        );
      } else {
        const payload = this.invoiceMapper.mapComprobanteToInvoicePayload(
          comprobante,
          empresa,
          clienteResult.registro,
          ubigeo,
        );

        if (comprobante.registro.hash_documento) {
          (payload as Record<string, unknown>).hash =
            comprobante.registro.hash_documento;
        }

        const tipoDoc = comprobante.registro.codigo_tipo_comprobante;
        pdfBuffer =
          tipoDoc === '07' || tipoDoc === '08'
            ? await this.facturacionClient.generarPdfNota(payload)
            : await this.facturacionClient.generarPdfFacturaBoleta(payload);
      }
    }

    const serie = comprobante.registro.serie;
    const numero = comprobante.registro.numero;
    const filename = `${serie}-${numero}-${formato}.pdf`;

    return { buffer: pdfBuffer, filename, formato };
  }

  mapComprobanteToInvoicePayload(
    comprobante: Awaited<ReturnType<ComprobantesModel['obtenerCompleto']>>,
    empresa: NonNullable<
      Awaited<ReturnType<ComprobantesModel['obtenerEmpresaEmisora']>>
    >,
    cliente: NonNullable<
      Awaited<ReturnType<ClientesModel['obtenerPorId']>>['registro']
    >,
    ubigeo: string,
  ) {
    return this.invoiceMapper.mapComprobanteToInvoicePayload(
      comprobante,
      empresa,
      cliente,
      ubigeo,
    );
  }

  private resolverEstadoSunatNombre(sunatResponse: SunatResponsePayload) {
    return estadoDesdeCdr(sunatResponse);
  }

  private resolverEstadoSunatDesdeConsulta(payload: unknown) {
    return estadoDesdeCdr(payload);
  }

  /** Igual que emitir, pero un CDR aceptado de voided implica baja. */
  private resolverEstadoBajaNombre(sunatResponse: SunatResponsePayload) {
    return this.resolverEstadoSunatNombre(sunatResponse);
  }

  private async assertFacturacionConfigurada() {
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
  }
}
