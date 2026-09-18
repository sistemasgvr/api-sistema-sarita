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
import type { ComprasElegiblesQueryDto, CreateRetencionDto, FiltroRetencionDto } from '../dto/retencion.dto';
import type { RetencionCompletoResult } from '../interfaces/retencion.interface';
import { RetencionMapper } from '../mappers/retencion.mapper';
import { RetencionesModel } from '../models/retenciones.model';

@Injectable()
export class RetencionesLogic {
  constructor(
    private readonly model: RetencionesModel,
    private readonly db: DatabaseService,
    private readonly facturacionClient: FacturacionApisperuClient,
    private readonly credentialsService: FacturacionCredentialsService,
    private readonly mapper: RetencionMapper,
  ) {}

  /** Misma envoltura paginada (`data` + `meta`) que el resto de listados. */
  async listar(filtros: FiltroRetencionDto) {
    const result = await this.model.listar({
      idEmpresa: filtros.idEmpresa,
      fechaDesde: filtros.fechaDesde,
      fechaHasta: filtros.fechaHasta,
      idProveedor: filtros.idProveedor,
      pagina: filtros.pagina ?? 1,
      tamano: filtros.tamano ?? 20,
    });
    return mapListResult(result, { pagina: filtros.pagina ?? 1, limite: filtros.tamano ?? 20 } as FiltroPaginacionDto);
  }

  /** Registro completo (data = registro), como el resto de módulos. */
  async obtenerPorId(id: number) {
    const result = await this.model.obtener(id);
    return mapSingleResult(result, `Retención ${id} no encontrada`);
  }

  private async obtener(id: number): Promise<RetencionCompletoResult> {
    const result = await this.model.obtener(id);
    if (result.error) throw new BadRequestException(result.error);
    if (!result.registro) throw new NotFoundException(`Retención ${id} no encontrada`);
    return result;
  }

  listarComprasElegibles(query: ComprasElegiblesQueryDto) {
    return this.model.listarComprasElegibles(query);
  }

  /** Series R001–R999 ya usadas por la empresa, con el correlativo que sigue. */
  async series(idEmpresa?: number) {
    return { series: await this.model.listarSeries(idEmpresa) };
  }

  /**
   * La retención nace de compras registradas (facturas del proveedor), del mismo
   * proveedor y en soles: proveedor, sucursal, importes y detalle salen de ellas. El documento queda pendiente de emisión al PSE.
   */
  async crear(dto: CreateRetencionDto, idUsuarioAuditoria?: number) {
    const tasa = await this.resolverTasa(dto.regimen, dto.tasa);
    const origenes = await this.model.obtenerCompras(dto.compras.map((c) => c.idCompra));
    const calculo = armarTributoDesdeOrigen(
      'retencion',
      {
        regimen: dto.regimen,
        tasa,
        fechaEmision: dto.fechaEmision,
        origenes: dto.compras.map((c) => ({ id: c.idCompra, fechaOperacion: c.fechaPago })),
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
        id_contraparte: o.id_proveedor,
        nombre_contraparte: o.nombre_proveedor,
        documento_contraparte: o.documento_proveedor,
        con_tributo: o.con_retencion,
        id_sucursal: o.id_sucursal,
      })),
    );

    const result = await this.model.crear({
      serie: dto.serie,
      fechaEmision: dto.fechaEmision,
      idEmpresa: dto.idEmpresa,
      idProveedor: calculo.idContraparte,
      idSucursal: calculo.idSucursal,
      regimen: dto.regimen,
      tasa: calculo.tasa,
      baseImponible: calculo.baseImponible,
      montoRetenido: calculo.montoTributo,
      montoPagado: calculo.montoNeto,
      observacion: dto.observacion,
      detalles: calculo.detalles.map((d) => ({
        id_compra: d.id_origen,
        tipo_doc: d.tipo_doc,
        num_doc: d.num_doc,
        fecha_emision: d.fecha_emision,
        fecha_retencion: d.fecha_operacion,
        moneda: d.moneda,
        imp_total: d.imp_total,
        imp_retenido: d.imp_tributo,
        imp_pagar: d.imp_neto,
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
    if (!encontrado) throw new BadRequestException(`Régimen de retención ${regimen} no válido`);
    if (encontrado.tasas.length === 0) {
      throw new BadRequestException(
        `El régimen de retención ${regimen} no tiene tasas registradas; agrégalas en el catálogo TasaRetencion`,
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
    const { regimenesRetencion, tasasRetencion } = await this.model.obtenerCatalogos();
    return asociarTasasARegimenes(regimenesRetencion, tasasRetencion ?? []);
  }

  async catalogos() {
    const { estadosSunat } = await this.model.obtenerCatalogos();
    return { regimenesRetencion: await this.regimenesConTasas(), estadosSunat };
  }

  /**
   * Envío a `retention/send` con las credenciales de la empresa emisora. El
   * estado se deduce del CDR (nunca de `success: true`), igual que en la GRE.
   */
  async emitir(id: number, dto: AuditoriaDto) {
    const doc = await this.obtener(id);
    const cabecera = doc.registro!;

    if (cabecera.nombre_estado_sunat === 'ACEPTADO') {
      throw new BadRequestException('La retención ya fue aceptada por SUNAT');
    }
    if (!cabecera.id_empresa) throw new BadRequestException('La retención no tiene empresa emisora');
    if (!cabecera.id_proveedor) throw new BadRequestException('La retención no tiene proveedor');

    const empresa = await obtenerEmpresaEmisoraPse(this.db, cabecera.id_empresa);
    const proveedor = await obtenerContrapartePse(this.db, cabecera.id_proveedor, 'Proveedor');
    await assertPseConfigurado(this.credentialsService, this.facturacionClient, cabecera.id_empresa);

    const payload = this.mapper.mapToRetentionPayload(doc, empresa, proveedor);
    const respuesta = await this.credentialsService.withEmpresa(cabecera.id_empresa, () =>
      this.facturacionClient.enviarRetencion(payload),
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
        tipo: 'retention_send',
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

  /** PDF y XML oficiales desde `retention/pdf` y `retention/xml`, guardados en base64. */
  async descargarPdfXml(id: number) {
    const doc = await this.obtener(id);
    const cabecera = doc.registro!;
    const empresa = await obtenerEmpresaEmisoraPse(this.db, cabecera.id_empresa);
    const proveedor = await obtenerContrapartePse(this.db, cabecera.id_proveedor, 'Proveedor');
    await assertPseConfigurado(this.credentialsService, this.facturacionClient, cabecera.id_empresa);
    const payload = this.mapper.mapToRetentionPayload(doc, empresa, proveedor);

    const [pdfBase64, xmlBase64] = await this.credentialsService.withEmpresa(cabecera.id_empresa, () =>
      Promise.all([this.facturacionClient.retencionPdf(payload), this.facturacionClient.retencionXml(payload)]),
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
    return { buffer: Buffer.from(base64, 'base64'), filename: `RETENCION-${cabecera.serie}-${cabecera.numero}.pdf` };
  }

  async obtenerXmlOficial(id: number) {
    const base64 = await this.documentoOficial(id, 'xml_oficial');
    if (!base64) return null;
    const cabecera = (await this.obtener(id)).registro!;
    return { buffer: Buffer.from(base64, 'base64'), filename: `RETENCION-${cabecera.serie}-${cabecera.numero}.xml` };
  }

  /** Usa la copia guardada; si no existe, la descarga una vez. */
  private async documentoOficial(id: number, clave: 'pdf_oficial' | 'xml_oficial') {
    const guardado = documentoOficialBase64((await this.obtener(id)).registro?.cdr_respuesta, clave);
    if (guardado) return guardado;
    await this.descargarPdfXml(id);
    return documentoOficialBase64((await this.obtener(id)).registro?.cdr_respuesta, clave);
  }
}
