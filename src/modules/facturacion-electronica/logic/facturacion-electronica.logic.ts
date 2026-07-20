import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { FacturacionApisperuClient } from '../../../integrations/facturacion-apisperu/facturacion-apisperu.client';
import {
  FacturacionComprobanteStatusDto,
  FacturacionDocumentoPayload,
  FacturacionLoginDto,
  FacturacionTicketStatusDto,
} from '../dto/facturacion-electronica.dto';

@Injectable()
export class FacturacionElectronicaLogic {
  constructor(
    private readonly facturacionClient: FacturacionApisperuClient,
  ) {}

  obtenerEstado() {
    return this.facturacionClient.getConfigStatus();
  }

  async verificarConexion() {
    this.assertConfigured();
    await this.facturacionClient.listarEmpresas();
    return {
      ok: true,
      message: 'Conexión exitosa con APIsPERU Facturación',
    };
  }

  async iniciarSesion(dto: FacturacionLoginDto) {
    this.facturacionClient.assertEnabled();
    const result = await this.facturacionClient.login(dto);
    return {
      token: result.token,
      expiresInHours: 24,
    };
  }

  async listarEmpresas() {
    this.assertConfigured();
    return this.facturacionClient.listarEmpresas();
  }

  async obtenerEmpresa(companyId: number) {
    this.assertConfigured();
    return this.facturacionClient.obtenerEmpresa(companyId);
  }

  async enviarFacturaBoleta(dto: FacturacionDocumentoPayload) {
    this.assertConfigured();
    return this.facturacionClient.enviarFacturaBoleta(dto);
  }

  async generarXmlFacturaBoleta(dto: FacturacionDocumentoPayload) {
    this.assertConfigured();
    const xml = await this.facturacionClient.generarXmlFacturaBoleta(dto);
    return { xml };
  }

  async consultarEstadoFacturaBoleta(query: FacturacionComprobanteStatusDto) {
    this.assertConfigured();
    return this.facturacionClient.consultarEstadoFacturaBoleta(query);
  }

  async enviarNota(dto: FacturacionDocumentoPayload) {
    this.assertConfigured();
    return this.facturacionClient.enviarNota(dto);
  }

  async enviarResumenDiario(dto: FacturacionDocumentoPayload) {
    this.assertConfigured();
    return this.facturacionClient.enviarResumenDiario(dto);
  }

  async consultarEstadoResumen(query: FacturacionTicketStatusDto) {
    this.assertConfigured();
    return this.facturacionClient.consultarEstadoResumen(query);
  }

  async enviarComunicacionBaja(dto: FacturacionDocumentoPayload) {
    this.assertConfigured();
    return this.facturacionClient.enviarComunicacionBaja(dto);
  }

  async consultarEstadoComunicacionBaja(query: FacturacionTicketStatusDto) {
    this.assertConfigured();
    return this.facturacionClient.consultarEstadoComunicacionBaja(query);
  }

  async enviarGuiaRemision(dto: FacturacionDocumentoPayload) {
    this.assertConfigured();
    return this.facturacionClient.enviarGuiaRemision(dto);
  }

  async consultarEstadoGuiaRemision(query: FacturacionTicketStatusDto) {
    this.assertConfigured();
    return this.facturacionClient.consultarEstadoGuiaRemision(query);
  }

  /**
   * Punto de extensión para mapear ven_comprobante → payload Invoice APIsPERU.
   * Implementado en ComprobantesLogic / ComprobanteInvoiceMapper.
   */
  mapComprobanteToInvoicePayload(): never {
    throw new BadRequestException(
      'Use ComprobantesLogic.mapComprobanteToInvoicePayload o POST /comprobantes/:id/emitir',
    );
  }

  private assertConfigured(): void {
    const status = this.facturacionClient.getConfigStatus();

    if (!status.enabled) {
      throw new ServiceUnavailableException(
        'La integración de facturación electrónica está deshabilitada',
      );
    }

    if (!status.configured) {
      throw new BadRequestException(
        'Configure FACTURACION_APISPERU_TOKEN o FACTURACION_APISPERU_USERNAME/PASSWORD en el entorno',
      );
    }
  }
}
