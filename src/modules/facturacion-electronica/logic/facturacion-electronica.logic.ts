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
    await this.assertConfigured();
    await this.facturacionClient.listarEmpresas();
    return {
      ok: true,
      message: 'Conexión exitosa con el servicio de facturación electrónica',
    };
  }

  async iniciarSesion(dto: FacturacionLoginDto) {
    await this.facturacionClient.assertEnabled();
    const result = await this.facturacionClient.login(dto);
    return {
      token: result.token,
      expiresInHours: 24,
    };
  }

  async listarEmpresas() {
    await this.assertConfigured();
    return this.facturacionClient.listarEmpresas();
  }

  async obtenerEmpresa(companyId: number) {
    await this.assertConfigured();
    return this.facturacionClient.obtenerEmpresa(companyId);
  }

  async enviarFacturaBoleta(dto: FacturacionDocumentoPayload) {
    await this.assertConfigured();
    return this.facturacionClient.enviarFacturaBoleta(dto);
  }

  async generarXmlFacturaBoleta(dto: FacturacionDocumentoPayload) {
    await this.assertConfigured();
    const xml = await this.facturacionClient.generarXmlFacturaBoleta(dto);
    return { xml };
  }

  async consultarEstadoFacturaBoleta(query: FacturacionComprobanteStatusDto) {
    await this.assertConfigured();
    return this.facturacionClient.consultarEstadoFacturaBoleta(query);
  }

  async enviarNota(dto: FacturacionDocumentoPayload) {
    await this.assertConfigured();
    return this.facturacionClient.enviarNota(dto);
  }

  async enviarResumenDiario(dto: FacturacionDocumentoPayload) {
    await this.assertConfigured();
    return this.facturacionClient.enviarResumenDiario(dto);
  }

  async consultarEstadoResumen(query: FacturacionTicketStatusDto) {
    await this.assertConfigured();
    return this.facturacionClient.consultarEstadoResumen(query);
  }

  async enviarComunicacionBaja(dto: FacturacionDocumentoPayload) {
    await this.assertConfigured();
    return this.facturacionClient.enviarComunicacionBaja(dto);
  }

  async consultarEstadoComunicacionBaja(query: FacturacionTicketStatusDto) {
    await this.assertConfigured();
    return this.facturacionClient.consultarEstadoComunicacionBaja(query);
  }

  async enviarGuiaRemision(dto: FacturacionDocumentoPayload) {
    await this.assertConfigured();
    return this.facturacionClient.enviarGuiaRemision(dto);
  }

  async consultarEstadoGuiaRemision(query: FacturacionTicketStatusDto) {
    await this.assertConfigured();
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

  private async assertConfigured(): Promise<void> {
    const status = await this.facturacionClient.getConfigStatus();

    if (!status.enabled) {
      throw new ServiceUnavailableException(
        'La integración de facturación electrónica está deshabilitada',
      );
    }

    if (!status.configured) {
      throw new BadRequestException(
        'Configure token o usuario/clave del PSE en Configuración → SUNAT (o variables de entorno de facturación)',
      );
    }
  }
}
