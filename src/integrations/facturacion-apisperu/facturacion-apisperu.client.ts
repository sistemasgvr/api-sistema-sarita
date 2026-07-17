import { HttpService } from '@nestjs/axios';
import {
  BadGatewayException,
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AxiosError, AxiosRequestConfig, AxiosResponse } from 'axios';
import { firstValueFrom } from 'rxjs';
import type {
  FacturacionApisperuCompanyPayload,
  FacturacionApisperuDocumentResponse,
  FacturacionApisperuLoginRequest,
  FacturacionApisperuLoginResponse,
  FacturacionApisperuPayload,
  FacturacionApisperuValidationError,
  FacturacionComprobanteStatusQuery,
  FacturacionConfigStatus,
  FacturacionResumenStatusQuery,
} from './interfaces/facturacion-apisperu.interface';

@Injectable()
export class FacturacionApisperuClient {
  private readonly logger = new Logger(FacturacionApisperuClient.name);
  private sessionToken: string | null = null;
  private sessionTokenExpiresAt = 0;

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
  ) {}

  getConfigStatus(): FacturacionConfigStatus {
    const enabled = this.isEnabled();
    const token = this.getStaticToken();
    const username = this.configService.get<string>('facturacion.username') ?? '';
    const password = this.configService.get<string>('facturacion.password') ?? '';
    const defaultRuc =
      this.configService.get<string>('facturacion.defaultRuc') ?? '';

    return {
      enabled,
      configured: enabled && (Boolean(token) || (Boolean(username) && Boolean(password))),
      baseUrl: this.getBaseUrl(),
      hasToken: Boolean(token),
      hasCredentials: Boolean(username) && Boolean(password),
      defaultRuc: defaultRuc || null,
    };
  }

  isEnabled(): boolean {
    return this.configService.get<boolean>('facturacion.enabled') !== false;
  }

  assertEnabled(): void {
    if (!this.isEnabled()) {
      throw new ServiceUnavailableException(
        'La integración de facturación electrónica está deshabilitada',
      );
    }
  }

  async login(
    credentials?: FacturacionApisperuLoginRequest,
  ): Promise<FacturacionApisperuLoginResponse> {
    this.assertEnabled();

    const username =
      credentials?.username ??
      this.configService.get<string>('facturacion.username');
    const password =
      credentials?.password ??
      this.configService.get<string>('facturacion.password');

    if (!username || !password) {
      throw new BadRequestException(
        'Credenciales de APIsPERU Facturación no configuradas',
      );
    }

    const response = await this.request<FacturacionApisperuLoginResponse>(
      'POST',
      '/auth/login',
      { username, password },
      { auth: false },
    );

    this.sessionToken = response.token;
    this.sessionTokenExpiresAt = Date.now() + 23 * 60 * 60 * 1000;

    return response;
  }

  async listarEmpresas(): Promise<FacturacionApisperuPayload[]> {
    return this.request<FacturacionApisperuPayload[]>('GET', '/companies');
  }

  async obtenerEmpresa(companyId: number): Promise<FacturacionApisperuPayload> {
    return this.request<FacturacionApisperuPayload>(
      'GET',
      `/companies/${companyId}`,
    );
  }

  async crearEmpresa(
    payload: FacturacionApisperuCompanyPayload,
  ): Promise<FacturacionApisperuPayload> {
    return this.request<FacturacionApisperuPayload>(
      'POST',
      '/companies',
      payload,
    );
  }

  async actualizarEmpresa(
    companyId: number,
    payload: Partial<FacturacionApisperuCompanyPayload>,
  ): Promise<FacturacionApisperuPayload> {
    return this.request<FacturacionApisperuPayload>(
      'PATCH',
      `/companies/${companyId}`,
      payload,
    );
  }

  async eliminarEmpresa(companyId: number): Promise<void> {
    await this.request<void>('DELETE', `/companies/${companyId}`);
  }

  async enviarFacturaBoleta(
    payload: FacturacionApisperuPayload,
  ): Promise<FacturacionApisperuDocumentResponse> {
    return this.request<FacturacionApisperuDocumentResponse>(
      'POST',
      '/invoice/send',
      payload,
    );
  }

  async generarXmlFacturaBoleta(
    payload: FacturacionApisperuPayload,
  ): Promise<string> {
    return this.request<string>('POST', '/invoice/xml', payload, {
      responseType: 'text',
    });
  }

  async generarPdfFacturaBoleta(
    payload: FacturacionApisperuPayload,
  ): Promise<Buffer> {
    const body = await this.buildPdfPayload(payload, 'a4');
    const data = await this.request<ArrayBuffer>('POST', '/invoice/pdf', body, {
      responseType: 'arraybuffer',
      accept: 'application/pdf',
    });

    return Buffer.from(data);
  }

  async consultarEstadoFacturaBoleta(
    query: FacturacionComprobanteStatusQuery,
  ): Promise<FacturacionApisperuPayload> {
    return this.request<FacturacionApisperuPayload>('GET', '/invoice/status', undefined, {
      params: this.withDefaultRuc(query),
    });
  }

  async enviarNota(payload: FacturacionApisperuPayload): Promise<FacturacionApisperuDocumentResponse> {
    return this.request<FacturacionApisperuDocumentResponse>(
      'POST',
      '/note/send',
      payload,
    );
  }

  async generarXmlNota(payload: FacturacionApisperuPayload): Promise<string> {
    return this.request<string>('POST', '/note/xml', payload, {
      responseType: 'text',
    });
  }

  async generarPdfNota(payload: FacturacionApisperuPayload): Promise<Buffer> {
    const body = await this.buildPdfPayload(payload, 'a4');
    const data = await this.request<ArrayBuffer>('POST', '/note/pdf', body, {
      responseType: 'arraybuffer',
      accept: 'application/pdf',
    });

    return Buffer.from(data);
  }

  async enviarResumenDiario(
    payload: FacturacionApisperuPayload,
  ): Promise<FacturacionApisperuDocumentResponse> {
    return this.request<FacturacionApisperuDocumentResponse>(
      'POST',
      '/summary/send',
      payload,
    );
  }

  async consultarEstadoResumen(
    query: FacturacionResumenStatusQuery,
  ): Promise<FacturacionApisperuPayload> {
    return this.request<FacturacionApisperuPayload>('GET', '/summary/status', undefined, {
      params: this.withDefaultRuc(query),
    });
  }

  async enviarComunicacionBaja(
    payload: FacturacionApisperuPayload,
  ): Promise<FacturacionApisperuDocumentResponse> {
    return this.request<FacturacionApisperuDocumentResponse>(
      'POST',
      '/voided/send',
      payload,
    );
  }

  async consultarEstadoComunicacionBaja(
    query: FacturacionResumenStatusQuery,
  ): Promise<FacturacionApisperuPayload> {
    return this.request<FacturacionApisperuPayload>('GET', '/voided/status', undefined, {
      params: this.withDefaultRuc(query),
    });
  }

  async enviarGuiaRemision(
    payload: FacturacionApisperuPayload,
  ): Promise<FacturacionApisperuDocumentResponse> {
    return this.request<FacturacionApisperuDocumentResponse>(
      'POST',
      '/despatch/send',
      payload,
    );
  }

  async consultarEstadoGuiaRemision(
    query: FacturacionComprobanteStatusQuery,
  ): Promise<FacturacionApisperuPayload> {
    return this.request<FacturacionApisperuPayload>('GET', '/despatch/status', undefined, {
      params: this.withDefaultRuc(query),
    });
  }

  /**
   * Arma el body del PDF con parámetros Greenter (logo + hash).
   * Sin logo, la plantilla A4 muestra el ícono roto.
   */
  private async buildPdfPayload(
    payload: FacturacionApisperuPayload,
    formato: 'a4' | 'ticket',
  ): Promise<FacturacionApisperuPayload> {
    const ruc = this.extractCompanyRuc(payload);
    const hash =
      typeof payload.hash === 'string' && payload.hash.trim()
        ? payload.hash.trim()
        : '';
    const logoBase64 = await this.resolveLogoBase64(ruc);

    const company =
      payload.company && typeof payload.company === 'object'
        ? { ...(payload.company as Record<string, unknown>) }
        : {};

    if (logoBase64) {
      company.logo = logoBase64;
    }

    const parameters: Record<string, unknown> = {
      system: {
        ...(logoBase64
          ? {
              // Greenter |image espera bytes; APIsPERU suele aceptar base64 del PNG.
              logo: logoBase64,
            }
          : {}),
        ...(hash ? { hash } : {}),
      },
      user: {
        header: '',
      },
    };

    return {
      ...payload,
      company,
      // Plantilla Greenter: invoice (A4) | ticket (80mm) — A4 es el que usa logo
      name: formato === 'ticket' ? 'ticket' : 'invoice',
      parameters,
      // Alias por si el wrapper usa "params"
      params: parameters,
    };
  }

  private extractCompanyRuc(payload: FacturacionApisperuPayload): string {
    const company = payload.company as { ruc?: string | number } | undefined;
    if (company?.ruc != null) return String(company.ruc);
    return this.configService.get<string>('facturacion.defaultRuc') ?? '';
  }

  private normalizeLogoBase64(value: string): string {
    const trimmed = value.trim();
    if (trimmed.startsWith('data:')) {
      const comma = trimmed.indexOf(',');
      return comma >= 0 ? trimmed.slice(comma + 1) : trimmed;
    }
    return trimmed;
  }

  /** Logo PNG/JPG en base64 (sin data:) desde la empresa en APIsPERU. */
  async obtenerLogoEmpresaBase64(ruc: string): Promise<string | null> {
    return this.resolveLogoBase64(ruc);
  }

  private async resolveLogoBase64(ruc: string): Promise<string | null> {
    const rucNorm = String(ruc ?? '').trim();

    try {
      const empresas = await this.listarEmpresas();
      if (!Array.isArray(empresas) || empresas.length === 0) {
        this.logger.warn('APIsPERU /companies no devolvió empresas');
        return null;
      }

      const empresa =
        (rucNorm
          ? empresas.find(
              (item) =>
                String((item as { ruc?: string | number }).ruc ?? '').trim() ===
                rucNorm,
            )
          : undefined) ?? empresas[0];

      const companyId = (empresa as { id?: number } | undefined)?.id;
      if (companyId == null) {
        this.logger.warn('Empresa APIsPERU sin id; no se puede obtener logo');
        return null;
      }

      // El listado suele devolver solo la ruta (ej. "10175332796/logo.png").
      // El detalle sí trae el PNG/JPG en base64 usable para PDFKit.
      const detail = await this.obtenerEmpresa(companyId);
      const logo = (detail as { logo?: string }).logo;

      if (typeof logo === 'string' && logo.trim()) {
        const base64 = await this.logoValueToBase64(logo.trim());
        if (this.looksLikeImageBase64(base64)) {
          return base64;
        }
        this.logger.warn(
          `Logo de empresa ${companyId} no es imagen base64 válida (len=${base64.length})`,
        );
      } else {
        this.logger.warn(`Empresa APIsPERU ${companyId} sin campo logo`);
      }
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`No se pudo obtener logo de APIsPERU: ${message}`);
    }

    return null;
  }

  private looksLikeImageBase64(value: string): boolean {
    const raw = this.normalizeLogoBase64(value).replace(/\s/g, '');
    if (raw.length < 64) return false;
    // PNG / JPEG / GIF / WEBP (webp raramente en logo)
    return (
      raw.startsWith('iVBOR') || // PNG
      raw.startsWith('/9j/') || // JPEG
      raw.startsWith('R0lGOD') || // GIF
      raw.startsWith('UklGR') // WEBP
    );
  }

  private async logoValueToBase64(logo: string): Promise<string> {
    if (logo.startsWith('http://') || logo.startsWith('https://')) {
      const response = await firstValueFrom(
        this.httpService.get<ArrayBuffer>(logo, {
          responseType: 'arraybuffer',
          timeout: this.getTimeoutMs(),
        }),
      );
      return Buffer.from(response.data).toString('base64');
    }

    return this.normalizeLogoBase64(logo);
  }

  private getBaseUrl(): string {
    return (
      this.configService.get<string>('facturacion.baseUrl') ??
      'https://facturacion.apisperu.com/api/v1'
    ).replace(/\/$/, '');
  }

  private getTimeoutMs(): number {
    return this.configService.get<number>('facturacion.timeoutMs') ?? 60_000;
  }

  private getStaticToken(): string {
    return this.configService.get<string>('facturacion.token') ?? '';
  }

  private withDefaultRuc<T extends { ruc?: string }>(
    query: T,
  ): Record<string, string | undefined> {
    if (query.ruc) return { ...query } as Record<string, string | undefined>;

    const defaultRuc = this.configService.get<string>('facturacion.defaultRuc');
    if (!defaultRuc) return { ...query } as Record<string, string | undefined>;

    return { ...query, ruc: defaultRuc };
  }

  private async resolveAuthToken(): Promise<string> {
    const staticToken = this.getStaticToken();
    if (staticToken) return staticToken;

    if (this.sessionToken && Date.now() < this.sessionTokenExpiresAt) {
      return this.sessionToken;
    }

    const login = await this.login();
    return login.token;
  }

  private async request<T>(
    method: AxiosRequestConfig['method'],
    path: string,
    data?: unknown,
    options?: {
      auth?: boolean;
      params?: Record<string, string | number | boolean | undefined>;
      responseType?: AxiosRequestConfig['responseType'];
      accept?: string;
    },
  ): Promise<T> {
    this.assertEnabled();

    const auth = options?.auth !== false;
    const headers: Record<string, string> = {
      Accept: options?.accept ?? 'application/json',
    };

    if (auth) {
      const token = await this.resolveAuthToken();
      headers.Authorization = `Bearer ${token}`;
    }

    if (data !== undefined) {
      headers['Content-Type'] = 'application/json';
    }

    const url = `${this.getBaseUrl()}${path}`;

    try {
      const response: AxiosResponse<T> = await firstValueFrom(
        this.httpService.request<T>({
          method,
          url,
          data,
          params: options?.params,
          headers,
          timeout: this.getTimeoutMs(),
          responseType: options?.responseType ?? 'json',
          validateStatus: (status) => status < 500,
        }),
      );

      if (response.status === 401) {
        throw new UnauthorizedException(
          'Credenciales inválidas en APIsPERU Facturación',
        );
      }

      if (response.status === 400) {
        throw new BadRequestException(
          this.formatValidationErrors(response.data),
        );
      }

      if (response.status >= 400) {
        throw new BadGatewayException(
          `APIsPERU Facturación respondió con estado ${response.status}`,
        );
      }

      return response.data;
    } catch (error: unknown) {
      if (
        error instanceof BadRequestException ||
        error instanceof UnauthorizedException ||
        error instanceof BadGatewayException
      ) {
        throw error;
      }

      const axiosError = error as AxiosError;
      this.logger.error(
        `Error APIsPERU ${method} ${path}: ${axiosError.message}`,
        axiosError.response?.data,
      );

      throw new BadGatewayException(
        'No se pudo comunicar con el servicio de facturación electrónica',
      );
    }
  }

  private formatValidationErrors(data: unknown): string {
    if (Array.isArray(data)) {
      return (data as FacturacionApisperuValidationError[])
        .map((item) => {
          const field = item.field ? `${item.field}: ` : '';
          return `${field}${item.message ?? 'Error de validación'}`;
        })
        .join('; ');
    }

    if (data && typeof data === 'object' && 'message' in data) {
      return String((data as { message: unknown }).message);
    }

    return 'Error de validación en APIsPERU Facturación';
  }
}
