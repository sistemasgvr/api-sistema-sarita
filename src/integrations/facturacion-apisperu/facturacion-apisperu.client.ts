import { HttpService } from '@nestjs/axios';
import {
  BadGatewayException,
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { AxiosError, AxiosRequestConfig, AxiosResponse } from 'axios';
import { firstValueFrom } from 'rxjs';
import {
  FacturacionCredentials,
  FacturacionCredentialsService,
} from '../facturacion-electronica/facturacion-credentials.service';
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
    private readonly credentialsService: FacturacionCredentialsService,
  ) {}

  async getConfigStatus(): Promise<FacturacionConfigStatus> {
    const creds = await this.credentialsService.resolve();
    const enabled = creds.enabled;
    const token = creds.token;
    const username = creds.username;
    const password = creds.password;

    return {
      enabled,
      configured:
        enabled &&
        (Boolean(token) || (Boolean(username) && Boolean(password))),
      baseUrl: creds.baseUrl,
      hasToken: Boolean(token),
      hasCredentials: Boolean(username) && Boolean(password),
      hasGreCredentials: Boolean(creds.clientId && creds.clientSecret),
      defaultRuc: creds.defaultRuc || null,
    };
  }

  async isEnabled(): Promise<boolean> {
    const creds = await this.credentialsService.resolve();
    return creds.enabled;
  }

  async assertEnabled(): Promise<void> {
    if (!(await this.isEnabled())) {
      throw new ServiceUnavailableException(
        'La integración de facturación electrónica está deshabilitada',
      );
    }
  }

  async login(
    credentials?: FacturacionApisperuLoginRequest,
  ): Promise<FacturacionApisperuLoginResponse> {
    await this.assertEnabled();
    const creds = await this.credentialsService.resolve();

    const username = credentials?.username ?? creds.username;
    const password = credentials?.password ?? creds.password;

    if (!username || !password) {
      throw new BadRequestException(
        'Credenciales de facturación electrónica no configuradas (usuario/clave PSE)',
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
      'PUT',
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
      params: await this.withDefaultRuc(query),
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
      params: await this.withDefaultRuc(query),
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
      params: await this.withDefaultRuc(query),
    });
  }

  async enviarGuiaRemision(
    payload: FacturacionApisperuPayload,
  ): Promise<FacturacionApisperuDocumentResponse> {
    const ruc = await this.extractCompanyRuc(payload);
    await this.asegurarCredencialesGreEnEmpresa(ruc);

    return this.request<FacturacionApisperuDocumentResponse>(
      'POST',
      '/despatch/send',
      payload,
    );
  }

  async consultarEstadoGuiaRemision(
    query: FacturacionResumenStatusQuery,
  ): Promise<FacturacionApisperuPayload> {
    return this.request<FacturacionApisperuPayload>('GET', '/despatch/status', undefined, {
      params: await this.withDefaultRuc(query),
    });
  }

  /**
   * APIsPERU exige client_id/client_secret GRE en la empresa (swagger tag despatch).
   * Los toma de configuración SUNAT (BD) o .env y los sincroniza vía PUT /companies/{id}.
   */
  async asegurarCredencialesGreEnEmpresa(ruc?: string): Promise<void> {
    const creds = await this.credentialsService.resolve();
    const { clientId, clientSecret } = creds;

    if (!clientId || !clientSecret) {
      throw new BadRequestException(
        'Configure client_id y client_secret OAuth GRE en Configuración → SUNAT (o variables de entorno de facturación).',
      );
    }

    const companyId = await this.resolveCompanyId(ruc, creds);
    if (companyId == null) {
      throw new BadRequestException(
        'No se encontró la empresa emisora en el PSE para sincronizar credenciales GRE',
      );
    }

    this.logger.log(
      `Sincronizando credenciales GRE (client_id) en empresa PSE ${companyId}`,
    );

    await this.actualizarEmpresa(companyId, {
      client_id: clientId,
      client_secret: clientSecret,
    });
  }

  private async resolveCompanyId(
    ruc?: string,
    creds?: FacturacionCredentials,
  ): Promise<number | null> {
    const resolved = creds ?? (await this.credentialsService.resolve());
    const rucNorm = String(ruc ?? resolved.defaultRuc ?? '').trim();

    const empresas = await this.listarEmpresas();
    if (!Array.isArray(empresas) || empresas.length === 0) {
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
    return companyId ?? null;
  }

  /**
   * Arma el body del PDF con parámetros Greenter (logo + hash).
   * Sin logo, la plantilla A4 muestra el ícono roto.
   */
  private async buildPdfPayload(
    payload: FacturacionApisperuPayload,
    formato: 'a4' | 'ticket',
  ): Promise<FacturacionApisperuPayload> {
    const ruc = await this.extractCompanyRuc(payload);
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

  private async extractCompanyRuc(
    payload: FacturacionApisperuPayload,
  ): Promise<string> {
    const company = payload.company as { ruc?: string | number } | undefined;
    if (company?.ruc != null) return String(company.ruc);
    const creds = await this.credentialsService.resolve();
    return creds.defaultRuc;
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
      const creds = await this.credentialsService.resolve();
      const response = await firstValueFrom(
        this.httpService.get<ArrayBuffer>(logo, {
          responseType: 'arraybuffer',
          timeout: creds.timeoutMs,
        }),
      );
      return Buffer.from(response.data).toString('base64');
    }

    return this.normalizeLogoBase64(logo);
  }

  private async withDefaultRuc<T extends { ruc?: string }>(
    query: T,
  ): Promise<Record<string, string | undefined>> {
    if (query.ruc) return { ...query } as Record<string, string | undefined>;

    const creds = await this.credentialsService.resolve();
    if (!creds.defaultRuc) {
      return { ...query } as Record<string, string | undefined>;
    }

    return { ...query, ruc: creds.defaultRuc };
  }

  private async resolveAuthToken(): Promise<string> {
    const creds = await this.credentialsService.resolve();
    if (creds.token) return creds.token;

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
    await this.assertEnabled();
    const creds = await this.credentialsService.resolve();

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

    const url = `${creds.baseUrl}${path}`;

    try {
      const response: AxiosResponse<T> = await firstValueFrom(
        this.httpService.request<T>({
          method,
          url,
          data,
          params: options?.params,
          headers,
          timeout: creds.timeoutMs,
          responseType: options?.responseType ?? 'json',
          validateStatus: (status) => status < 500,
        }),
      );

      if (response.status === 401) {
        throw new UnauthorizedException(
          'Credenciales inválidas en el servicio de facturación electrónica',
        );
      }

      if (response.status === 400) {
        this.logger.warn(
          `APIsPERU 400 ${method} ${path}: ${this.safeJson(response.data)}`,
        );
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

      const providerMessage = this.extractProviderErrorMessage(
        axiosError.response?.data,
      );
      throw new BadGatewayException(
        providerMessage
          ? `APIsPERU Facturación: ${providerMessage}`
          : 'No se pudo comunicar con el servicio de facturación electrónica',
      );
    }
  }

  private extractProviderErrorMessage(data: unknown): string | null {
    if (!data || typeof data !== 'object') return null;
    const obj = data as Record<string, unknown>;
    if (typeof obj.error === 'string' && obj.error.trim()) {
      return obj.error.trim();
    }
    if (typeof obj.message === 'string' && obj.message.trim()) {
      return obj.message.trim();
    }
    return null;
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

    if (data && typeof data === 'object') {
      const obj = data as Record<string, unknown>;

      if (typeof obj.message === 'string' && obj.message.trim()) {
        const payloadHint =
          obj.payload != null ? ` | ${this.safeJson(obj.payload).slice(0, 400)}` : '';
        return `${obj.message}${payloadHint}`;
      }

      if (Array.isArray(obj.errors)) {
        return (obj.errors as FacturacionApisperuValidationError[])
          .map((item) => {
            const field = item.field ? `${item.field}: ` : '';
            return `${field}${item.message ?? 'Error de validación'}`;
          })
          .join('; ');
      }

      if (obj.errors && typeof obj.errors === 'object') {
        return Object.entries(obj.errors as Record<string, unknown>)
          .map(([field, value]) => {
            const msg = Array.isArray(value)
              ? value.map(String).join(', ')
              : String(value);
            return `${field}: ${msg}`;
          })
          .join('; ');
      }

      if (typeof obj.error === 'string' && obj.error.trim()) {
        return obj.error;
      }

      if (obj.error && typeof obj.error === 'object') {
        const err = obj.error as Record<string, unknown>;
        if (typeof err.message === 'string') {
          const code = err.code != null ? `[${String(err.code)}] ` : '';
          return `${code}${err.message}`;
        }
      }

      const serialized = this.safeJson(data);
      if (serialized && serialized !== '{}') {
        return `Error de validación en APIsPERU Facturación: ${serialized.slice(0, 500)}`;
      }
    }

    if (typeof data === 'string' && data.trim()) {
      return data.trim().slice(0, 500);
    }

    return 'Error de validación en APIsPERU Facturación';
  }

  private safeJson(value: unknown): string {
    try {
      return JSON.stringify(value);
    } catch {
      return String(value);
    }
  }
}
