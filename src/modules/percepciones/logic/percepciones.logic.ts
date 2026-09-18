import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import { mapListResult, mapSingleResult } from '../../../common/helpers/auth-response.helper';
import { armarTributoDesdeOrigen } from '../../../common/helpers/tributo-desde-origen.helper';
import {
  asociarTasasARegimenes,
  assertPseConfigurado,
  documentoOficialBase64,
  estadoDesdeRespuestaPse,
  leerCdrJson,
  mismaTasa,
  obtenerContrapartePse,
  obtenerEmpresaEmisoraPse,
  resolverIdEstadoSunat,
  type RegimenConTasas,
} from '../../../common/helpers/comprobante-sunat.helper';
import { DatabaseService } from '../../../database/database.service';
import { FacturacionApisperuClient } from '../../../integrations/facturacion-apisperu/facturacion-apisperu.client';
import { FacturacionCredentialsService } from '../../../integrations/facturacion-electronica/facturacion-credentials.service';
import type { ComprobantesElegiblesQueryDto, CreatePercepcionDto, FiltroPercepcionDto } from '../dto/percepcion.dto';
import type { PercepcionCompletoResult, PercepcionDetalleRegistro } from '../interfaces/percepcion.interface';
import { PercepcionMapper } from '../mappers/percepcion.mapper';
import { PercepcionesModel } from '../models/percepciones.model';

@Injectable()
export class PercepcionesLogic {
  constructor(
    private readonly model: PercepcionesModel,
    private readonly db: DatabaseService,
    private readonly facturacionClient: FacturacionApisperuClient,
    private readonly credentialsService: FacturacionCredentialsService,
    private readonly mapper: PercepcionMapper,
  ) {}

  /** Misma envoltura paginada (`data` + `meta`) que el resto de listados. */
  async listar(filtros: FiltroPercepcionDto) {
    const result = await this.model.listar({
      idEmpresa: filtros.idEmpresa,
      fechaDesde: filtros.fechaDesde,
      fechaHasta: filtros.fechaHasta,
      idCliente: filtros.idCliente,
      pagina: filtros.pagina ?? 1,
      tamano: filtros.tamano ?? 20,
    });
    return mapListResult(result, { pagina: filtros.pagina ?? 1, limite: filtros.tamano ?? 20 } as FiltroPaginacionDto);
  }

  /** Registro completo (data = registro), como el resto de módulos. */
  async obtenerPorId(id: number) {
    const result = await this.model.obtener(id);
    return mapSingleResult(result, `Percepción ${id} no encontrada`);
  }

  private async obtener(id: number): Promise<PercepcionCompletoResult> {
    const result = await this.model.obtener(id);
    if (result.error) throw new BadRequestException(result.error);
    if (!result.registro) throw new NotFoundException(`Percepción ${id} no encontrada`);
    return result;
  }

  listarComprobantesElegibles(query: ComprobantesElegiblesQueryDto) {
    return this.model.listarComprobantesElegibles(query);
  }

  /** Series P001–P999 ya usadas por la empresa, con el correlativo que sigue. */
  async series(idEmpresa?: number) {
    return { series: await this.model.listarSeries(idEmpresa) };
  }

  /**
   * La percepción nace de comprobantes de venta ya aceptados por SUNAT, del
   * mismo cliente y en soles: cliente, sucursal, importes y detalle salen de
   * ellos. El documento queda pendiente de emisión al PSE.
   */
  async crear(dto: CreatePercepcionDto, idUsuarioAuditoria?: number) {
    const tasa = await this.resolverTasa(dto.regimen, dto.tasa);
    const origenes = await this.model.obtenerComprobantes(dto.comprobantes.map((c) => c.idComprobante));
    const calculo = armarTributoDesdeOrigen(
      'percepcion',
      {
        regimen: dto.regimen,
        tasa,
        fechaEmision: dto.fechaEmision,
        origenes: dto.comprobantes.map((c) => ({ id: c.idComprobante, fechaOperacion: c.fechaCobro })),
      },
      origenes.map((o) => ({
        id: o.id,
        estado: o.estado,
        serie: o.serie,
        numero: o.numero,
        fecha: o.fecha,
        tipo_doc: o.tipo_doc,
        total: o.total,
        moneda: o.moneda,
        id_contraparte: o.id_cliente,
        nombre_contraparte: o.nombre_cliente,
        documento_contraparte: o.documento_cliente,
        nombre_estado_sunat: o.nombre_estado_sunat,
        con_tributo: o.con_percepcion,
      })),
    );

    const result = await this.model.crear({
      serie: dto.serie,
      fechaEmision: dto.fechaEmision,
      idEmpresa: dto.idEmpresa,
      idCliente: calculo.idContraparte,
      idSucursal: calculo.idSucursal,
      regimen: dto.regimen,
      tasa: calculo.tasa,
      baseImponible: calculo.baseImponible,
      montoPercibido: calculo.montoTributo,
      montoCobrado: calculo.montoNeto,
      observacion: dto.observacion,
      detalles: calculo.detalles.map((d) => ({
        id_comprobante: d.id_origen,
        tipo_doc: d.tipo_doc,
        num_doc: d.num_doc,
        fecha_emision: d.fecha_emision,
        fecha_percepcion: d.fecha_operacion,
        moneda: d.moneda,
        imp_total: d.imp_total,
        imp_percibido: d.imp_tributo,
        imp_cobrar: d.imp_neto,
      })),
      idUsuarioAuditoria,
    });

    if (result.error) throw new BadRequestException(result.error);
    return result;
  }

  /**
   * La tasa la fija el catálogo, no el cliente: si no viene se toma la del
   * régimen y si viene debe ser una de las registradas para ese régimen.
   */
  private async resolverTasa(regimen: string, tasa?: number): Promise<number> {
    const encontrado = (await this.regimenesConTasas()).find((r) => (r.descripcion ?? '').trim() === regimen);
    if (!encontrado) throw new BadRequestException(`Régimen de percepción ${regimen} no válido`);
    if (encontrado.tasas.length === 0) {
      throw new BadRequestException(
        `El régimen de percepción ${regimen} no tiene tasas registradas; agrégalas en el catálogo TasaPercepcion`,
      );
    }
    if (tasa == null) return encontrado.tasa!;
    if (!encontrado.tasas.some((t) => mismaTasa(t.tasa, tasa))) {
      const validas = encontrado.tasas.map((t) => t.etiqueta).join(', ');
      throw new BadRequestException(`La tasa ${tasa}% no está registrada para el régimen ${regimen} (tasas: ${validas})`);
    }
    return tasa;
  }

  private async regimenesConTasas(): Promise<RegimenConTasas[]> {
    const { regimenesPercepcion, tasasPercepcion } = await this.model.obtenerCatalogos();
    return asociarTasasARegimenes(regimenesPercepcion, tasasPercepcion ?? []);
  }

  async catalogos() {
    const { estadosSunat } = await this.model.obtenerCatalogos();
    return { regimenesPercepcion: await this.regimenesConTasas(), estadosSunat };
  }

  /**
   * Envío a `perception/send` con las credenciales de la empresa emisora. El
   * estado se deduce del CDR (nunca de `success: true`), igual que en la GRE.
   */
  async emitir(id: number, dto: AuditoriaDto) {
    const doc = await this.obtener(id);
    const cabecera = doc.registro!;

    if (cabecera.nombre_estado_sunat === 'ACEPTADO') {
      throw new BadRequestException('La percepción ya fue aceptada por SUNAT');
    }
    if (!cabecera.id_empresa) throw new BadRequestException('La percepción no tiene empresa emisora');
    if (!cabecera.id_cliente) throw new BadRequestException('La percepción no tiene cliente');
    await this.assertComprobantesAceptados(cabecera.detalles);

    const empresa = await obtenerEmpresaEmisoraPse(this.db, cabecera.id_empresa);
    const cliente = await obtenerContrapartePse(this.db, cabecera.id_cliente, 'Cliente');
    await assertPseConfigurado(this.credentialsService, this.facturacionClient, cabecera.id_empresa);

    const payload = this.mapper.mapToPerceptionPayload(doc, empresa, cliente);
    const respuesta = await this.credentialsService.withEmpresa(cabecera.id_empresa, () =>
      this.facturacionClient.enviarPercepcion(payload),
    );

    const sunatResponse = (respuesta.sunatResponse ?? {}) as { ticket?: string };
    const estado = estadoDesdeRespuestaPse(respuesta.sunatResponse ?? respuesta);
    const idEstadoSunat = await resolverIdEstadoSunat(this.db, estado);

    const actualizado = await this.model.registrarRespuestaSunat(id, {
      idEstadoSunat: idEstadoSunat ?? undefined,
      ticketSunat: sunatResponse.ticket ?? undefined,
      hashDocumento: respuesta.hash ?? undefined,
      xmlFirmado: respuesta.xml ?? undefined,
      cdrRespuesta: JSON.stringify({
        ...leerCdrJson(cabecera.cdr_respuesta),
        tipo: 'perception_send',
        respuesta: respuesta.sunatResponse ?? respuesta,
      }),
      idUsuarioAuditoria: dto.idUsuarioAuditoria,
    });

    if (actualizado.error) throw new BadRequestException(actualizado.error);

    return {
      documento: actualizado.registro,
      sunat: {
        estado,
        ticket: sunatResponse.ticket ?? null,
        respuesta: respuesta.sunatResponse ?? null,
      },
    };
  }

  /**
   * La percepción se puede armar sobre comprobantes pendientes de envío, pero
   * SUNAT solo la acepta si los comprobantes que referencia ya están aceptados.
   */
  private async assertComprobantesAceptados(detalles: PercepcionDetalleRegistro[]) {
    const ids = detalles.filter((d) => d.estado === 1 && d.id_comprobante != null).map((d) => d.id_comprobante!);
    const comprobantes = await this.model.obtenerComprobantes(ids);
    const noAceptados = comprobantes
      .filter((c) => c.nombre_estado_sunat !== 'ACEPTADO')
      .map((c) => `${c.serie}-${c.numero} (${c.nombre_estado_sunat ?? 'sin enviar'})`);
    if (noAceptados.length > 0) {
      throw new BadRequestException(
        `Emite primero a SUNAT los comprobantes de la percepción: ${noAceptados.join(', ')}`,
      );
    }
  }

  /** PDF y XML oficiales desde `perception/pdf` y `perception/xml`, guardados en base64. */
  async descargarPdfXml(id: number) {
    const doc = await this.obtener(id);
    const cabecera = doc.registro!;
    const empresa = await obtenerEmpresaEmisoraPse(this.db, cabecera.id_empresa);
    const cliente = await obtenerContrapartePse(this.db, cabecera.id_cliente, 'Cliente');
    await assertPseConfigurado(this.credentialsService, this.facturacionClient, cabecera.id_empresa);
    const payload = this.mapper.mapToPerceptionPayload(doc, empresa, cliente);

    const [pdfBase64, xmlBase64] = await this.credentialsService.withEmpresa(cabecera.id_empresa, () =>
      Promise.all([this.facturacionClient.percepcionPdf(payload), this.facturacionClient.percepcionXml(payload)]),
    );

    if (!pdfBase64 && !xmlBase64) {
      throw new BadRequestException('No se pudieron descargar el PDF ni el XML desde APIsPERU');
    }

    const cdrActual = leerCdrJson(cabecera.cdr_respuesta);
    if (pdfBase64) cdrActual.pdf_oficial = pdfBase64;
    if (xmlBase64) cdrActual.xml_oficial = xmlBase64;
    cdrActual.fecha_descarga_oficial = new Date().toISOString();

    await this.model.registrarRespuestaSunat(id, { cdrRespuesta: JSON.stringify(cdrActual) });

    return { pdfDescargado: Boolean(pdfBase64), xmlDescargado: Boolean(xmlBase64) };
  }

  async obtenerPdfOficial(id: number) {
    const base64 = await this.documentoOficial(id, 'pdf_oficial');
    if (!base64) return null;
    const cabecera = (await this.obtener(id)).registro!;
    return { buffer: Buffer.from(base64, 'base64'), filename: `PERCEPCION-${cabecera.serie}-${cabecera.numero}.pdf` };
  }

  async obtenerXmlOficial(id: number) {
    const base64 = await this.documentoOficial(id, 'xml_oficial');
    if (!base64) return null;
    const cabecera = (await this.obtener(id)).registro!;
    return { buffer: Buffer.from(base64, 'base64'), filename: `PERCEPCION-${cabecera.serie}-${cabecera.numero}.xml` };
  }

  /** Usa la copia guardada; si no existe, la descarga una vez. */
  private async documentoOficial(id: number, clave: 'pdf_oficial' | 'xml_oficial') {
    const guardado = documentoOficialBase64((await this.obtener(id)).registro?.cdr_respuesta, clave);
    if (guardado) return guardado;
    await this.descargarPdfXml(id);
    return documentoOficialBase64((await this.obtener(id)).registro?.cdr_respuesta, clave);
  }
}
