import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import { mapListResult } from '../../../common/helpers/auth-response.helper';
import {
  assertPseConfigurado,
  documentoOficialBase64,
  estadoDesdeRespuestaPse,
  leerCdrJson,
  obtenerContrapartePse,
  obtenerEmpresaEmisoraPse,
  resolverIdEstadoSunat,
} from '../../../common/helpers/comprobante-sunat.helper';
import { DatabaseService } from '../../../database/database.service';
import { FacturacionApisperuClient } from '../../../integrations/facturacion-apisperu/facturacion-apisperu.client';
import { FacturacionCredentialsService } from '../../../integrations/facturacion-electronica/facturacion-credentials.service';
import type { CreateRetencionDto, FiltroRetencionDto } from '../dto/retencion.dto';
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

  async obtener(id: number): Promise<RetencionCompletoResult> {
    const result = await this.model.obtener(id);
    if (result.error) throw new BadRequestException(result.error);
    if (!result.registro) throw new NotFoundException(`Retención ${id} no encontrada`);
    return result;
  }

  async crear(dto: CreateRetencionDto, idUsuarioAuditoria?: number) {
    const result = await this.model.crear({
      serie: dto.serie,
      fechaEmision: dto.fechaEmision,
      idEmpresa: dto.idEmpresa,
      idProveedor: dto.idProveedor,
      idSucursal: dto.idSucursal,
      regimen: dto.regimen,
      tasa: dto.tasa,
      baseImponible: dto.baseImponible,
      montoRetenido: dto.montoRetenido,
      montoPagado: dto.montoPagado,
      observacion: dto.observacion,
      detalles: dto.detalles,
      idUsuarioAuditoria,
    });

    if (result.error) throw new BadRequestException(result.error);
    return result;
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
