import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { FacturacionApisperuClient } from '../../../integrations/facturacion-apisperu/facturacion-apisperu.client';
import type { FacturacionApisperuDocumentResponse } from '../../../integrations/facturacion-apisperu/interfaces/facturacion-apisperu.interface';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ClientesModel } from '../../clientes/models/clientes.model';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  CreateComprobantesDto,
  FiltroComprobantesDto,
  RegistrarRespuestaSunatDto,
  SiguienteNumeroQueryDto,
  UpdateComprobantesDto,
} from '../dto/comprobantes.dto';
import { ComprobanteInvoiceMapper } from '../mappers/comprobante-invoice.mapper';
import { ComprobantesModel } from '../models/comprobantes.model';
import type { SiguienteNumeroResult } from '../models/comprobantes.model';
import { ComprobanteTicketPdfGenerator } from '../services/comprobante-ticket-pdf.generator';

interface SunatResponsePayload {
  success?: boolean;
  error?: { code?: string; message?: string };
  ticket?: string;
  cdrResponse?: { accepted?: boolean; code?: string; description?: string };
}

@Injectable()
export class ComprobantesLogic {
  constructor(
    private readonly model: ComprobantesModel,
    private readonly clientesModel: ClientesModel,
    private readonly facturacionClient: FacturacionApisperuClient,
    private readonly invoiceMapper: ComprobanteInvoiceMapper,
    private readonly ticketPdfGenerator: ComprobanteTicketPdfGenerator,
  ) {}

  async listar(filtros: FiltroComprobantesDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerCompleto(id);

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
    };
  }

  async obtenerCatalogosPos() {
    return this.model.obtenerCatalogosPos();
  }

  async obtenerSiguienteNumero(query: SiguienteNumeroQueryDto): Promise<SiguienteNumeroResult> {
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
    const result = await this.model.actualizar(id, dto);
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

  async emitir(id: number, dto: AuditoriaDto) {
    this.assertFacturacionConfigurada();

    const comprobante = await this.model.obtenerCompleto(id);

    if (comprobante.error) {
      throw new BadRequestException(comprobante.error);
    }

    if (!comprobante.registro) {
      throw new NotFoundException(`Comprobante ${id} no encontrado`);
    }

    if (comprobante.registro.nombre_estado_sunat === 'ACEPTADO') {
      throw new BadRequestException('El comprobante ya fue aceptado por SUNAT');
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

    const ubigeo = clienteResult.registro.id_distrito
      ? await this.model.obtenerCodigoUbigeoDistrito(clienteResult.registro.id_distrito)
      : '150101';

    const payload = this.invoiceMapper.mapComprobanteToInvoicePayload(
      comprobante,
      empresa,
      clienteResult.registro,
      ubigeo,
    );

    const tipoDoc = comprobante.registro.codigo_tipo_comprobante;
    let respuesta: FacturacionApisperuDocumentResponse;

    if (tipoDoc === '07' || tipoDoc === '08') {
      respuesta = await this.facturacionClient.enviarNota(payload);
    } else {
      respuesta = await this.facturacionClient.enviarFacturaBoleta(payload);
    }

    const sunatResponse = (respuesta.sunatResponse ?? {}) as SunatResponsePayload;
    const estadoSunatNombre = this.resolverEstadoSunatNombre(sunatResponse);
    const idEstadoSunat = await this.model.resolverIdEstadoSunat(estadoSunatNombre);

    const comprobanteActualizado = await this.model.registrarRespuestaSunat(id, {
      idEstadoSunat: idEstadoSunat ?? undefined,
      ticketSunat: sunatResponse.ticket ?? undefined,
      hashDocumento: respuesta.hash ?? undefined,
      xmlFirmado: respuesta.xml ?? undefined,
      cdrRespuesta: JSON.stringify(respuesta.sunatResponse ?? respuesta),
      idUsuarioAuditoria: dto.idUsuarioAuditoria,
    });

    if (comprobanteActualizado.error) {
      throw new BadRequestException(comprobanteActualizado.error);
    }

    return {
      comprobante: comprobanteActualizado.registro,
      sunat: {
        estado: estadoSunatNombre,
        hash: respuesta.hash ?? null,
        ticket: sunatResponse.ticket ?? null,
        respuesta: respuesta.sunatResponse ?? null,
      },
    };
  }

  async generarPdf(id: number, formato: 'a4' | 'ticket' = 'a4') {
    this.assertFacturacionConfigurada();

    const comprobante = await this.model.obtenerCompleto(id);

    if (comprobante.error) {
      throw new BadRequestException(comprobante.error);
    }

    if (!comprobante.registro) {
      throw new NotFoundException(`Comprobante ${id} no encontrado`);
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

    const ubigeo = clienteResult.registro.id_distrito
      ? await this.model.obtenerCodigoUbigeoDistrito(clienteResult.registro.id_distrito)
      : '150101';

    let pdfBuffer: Buffer;

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
        ;(payload as Record<string, unknown>).hash =
          comprobante.registro.hash_documento;
      }

      const tipoDoc = comprobante.registro.codigo_tipo_comprobante;
      pdfBuffer =
        tipoDoc === '07' || tipoDoc === '08'
          ? await this.facturacionClient.generarPdfNota(payload)
          : await this.facturacionClient.generarPdfFacturaBoleta(payload);
    }

    const serie = comprobante.registro.serie;
    const numero = comprobante.registro.numero;
    const filename = `${serie}-${numero}-${formato}.pdf`;

    return { buffer: pdfBuffer, filename, formato };
  }

  mapComprobanteToInvoicePayload(
    comprobante: Awaited<ReturnType<ComprobantesModel['obtenerCompleto']>>,
    empresa: NonNullable<Awaited<ReturnType<ComprobantesModel['obtenerEmpresaEmisora']>>>,
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

  private assertFacturacionConfigurada() {
    const status = this.facturacionClient.getConfigStatus();

    if (!status.enabled) {
      throw new ServiceUnavailableException(
        'La integración de facturación electrónica está deshabilitada',
      );
    }

    if (!status.configured) {
      throw new BadRequestException(
        'Configure FACTURACION_APISPERU_TOKEN o credenciales en el entorno',
      );
    }
  }
}
