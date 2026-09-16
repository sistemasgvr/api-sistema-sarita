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
  GreEmpresaVerificacion,
  GreEntorno,
  GreSincronizacionResultado,
} from './interfaces/facturacion-apisperu.interface';

/** Empresa tal como la devuelve GET /companies/{id} (campos que importan a GRE). */
interface EmpresaPse {
  id?: number;
  ruc?: string | number;
  environment?: string | { nombre?: string; api_cpe_url?: string; auth_url?: string };
  client_id?: string;
  sol_user?: string;
}

/**
 * Credenciales OAuth públicas del simulador GRE de SUNAT (gre-test.nubefact.com),
 * las únicas que autentica el entorno BETA del PSE (Greenter / Lycet .env.test).
 */
const GRE_TEST_CLIENT_ID = 'test-85e5b0ae-255c-4891-a595-0b98c65c9854';
const GRE_TEST_CLIENT_SECRET = 'test-Hty/M6QshYvPgItX2P0+Kw==';
const GRE_TEST_SOL_USER = 'MODDATOS';
const GRE_TEST_URL = /^https:\/\/gre-test\.nubefact\.com\/v1\/?$/;

@Injectable()
export class FacturacionApisperuClient {
  private readonly logger = new Logger(FacturacionApisperuClient.name);

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
        enabled && (Boolean(token) || (Boolean(username) && Boolean(password))),
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
    return this.request<FacturacionApisperuPayload>(
      'GET',
      '/invoice/status',
      undefined,
      {
        params: await this.withDefaultRuc(query),
      },
    );
  }

  async enviarNota(
    payload: FacturacionApisperuPayload,
  ): Promise<FacturacionApisperuDocumentResponse> {
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
    return this.request<FacturacionApisperuPayload>(
      'GET',
      '/summary/status',
      undefined,
      {
        params: await this.withDefaultRuc(query),
      },
    );
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
    return this.request<FacturacionApisperuPayload>(
      'GET',
      '/voided/status',
      undefined,
      {
        params: await this.withDefaultRuc(query),
      },
    );
  }

  /**
   * Envía la GRE. No modifica la empresa del PSE: la sincronización de
   * credenciales es una acción explícita de configuración
   * (`sincronizarCredencialesGre`). Aquí solo se verifica que el entorno y las
   * credenciales registradas permitan el envío.
   */
  async enviarGuiaRemision(
    payload: FacturacionApisperuPayload,
    verificacion?: GreEmpresaVerificacion,
  ): Promise<FacturacionApisperuDocumentResponse> {
    const ruc = await this.extractCompanyRuc(payload);
    const estado = verificacion ?? (await this.verificarEmpresaGre(ruc));
    if (!estado.listo) {
      throw new BadRequestException(
        `La empresa no está lista para emitir GRE: ${estado.problemas.join('; ')}`,
      );
    }

    try {
      return await this.request<FacturacionApisperuDocumentResponse>(
        'POST',
        '/despatch/send',
        payload,
      );
    } catch (error: unknown) {
      // APIsPERU responde 500 "Error al comunicarse con el servidor interno"
      // cuando su llamada a SUNAT (OAuth GRE) falla: el mensaje no dice nada
      // y el usuario revisa el payload en vano. Se le agrega el motivo más
      // probable a partir de cómo está configurada la empresa en el PSE.
      if (error instanceof BadGatewayException) {
        throw new BadGatewayException(
          `${error.message}${this.diagnosticoEntornoGre(estado)}`,
        );
      }
      throw error;
    }
  }

  /**
   * PDF oficial (binario, `application/pdf` según el swagger) de un documento
   * ya construido, devuelto en base64. `null` si el PSE no pudo generarlo:
   * el llamador decide si eso es error o solo «sin PDF disponible».
   */
  private async documentoPdfBase64(path: string, payload: FacturacionApisperuPayload): Promise<string | null> {
    try {
      const data = await this.request<ArrayBuffer>('POST', path, payload, {
        responseType: 'arraybuffer',
        accept: 'application/pdf',
      });
      const buffer = Buffer.from(data);
      return buffer.subarray(0, 5).toString('ascii') === '%PDF-' ? buffer.toString('base64') : null;
    } catch (error: unknown) {
      this.logger.warn(`No se pudo generar PDF (${path}): ${error instanceof Error ? error.message : String(error)}`);
      return null;
    }
  }

  /** XML firmado (`text/xml`) de un documento ya construido, en base64. */
  private async documentoXmlBase64(path: string, payload: FacturacionApisperuPayload): Promise<string | null> {
    try {
      const data = await this.request<string>('POST', path, payload, {
        responseType: 'text',
        accept: 'text/xml',
      });
      const xml = typeof data === 'string' ? data.trim() : '';
      return xml ? Buffer.from(xml, 'utf8').toString('base64') : null;
    } catch (error: unknown) {
      this.logger.warn(`No se pudo generar XML (${path}): ${error instanceof Error ? error.message : String(error)}`);
      return null;
    }
  }

  despatchPdf(payload: FacturacionApisperuPayload) {
    return this.documentoPdfBase64('/despatch/pdf', payload);
  }

  despatchXml(payload: FacturacionApisperuPayload) {
    return this.documentoXmlBase64('/despatch/xml', payload);
  }

  percepcionPdf(payload: FacturacionApisperuPayload) {
    return this.documentoPdfBase64('/perception/pdf', payload);
  }

  percepcionXml(payload: FacturacionApisperuPayload) {
    return this.documentoXmlBase64('/perception/xml', payload);
  }

  retencionPdf(payload: FacturacionApisperuPayload) {
    return this.documentoPdfBase64('/retention/pdf', payload);
  }

  retencionXml(payload: FacturacionApisperuPayload) {
    return this.documentoXmlBase64('/retention/xml', payload);
  }

  private diagnosticoEntornoGre(estado: GreEmpresaVerificacion): string {
    if (estado.entorno === 'beta' && !estado.esCredencialPrueba) {
      return (
        ` — La empresa está en entorno BETA del PSE (GRE contra ${estado.apiCpeUrl || 'gre-test.nubefact.com'}), ` +
        'que solo acepta las credenciales OAuth de prueba de SUNAT. Usa «Sincronizar configuración GRE» en Configuración → SUNAT ' +
        'o cambia la empresa a PRODUCCIÓN en APIsPERU para usar el client_id generado en SOL.'
      );
    }
    if (estado.entorno === 'produccion' && estado.esCredencialPrueba) {
      return (
        ' — La empresa está en PRODUCCIÓN pero el client_id GRE es el de prueba (test-…). ' +
        'Genera las credenciales reales en SUNAT SOL (Empresas → Comprobantes de pago → Credenciales API) y regístralas en Configuración → SUNAT.'
      );
    }
    return estado.entornoNombre
      ? ` — Revisa en APIsPERU las credenciales OAuth GRE de la empresa (entorno ${estado.entornoNombre}).`
      : '';
  }

  private normalizarEntorno(nombre: string | null | undefined): GreEntorno | null {
    const value = (nombre ?? '').trim().toLowerCase();
    if (!value) return null;
    if (value.includes('beta') || value.includes('test') || value.includes('prueba')) return 'beta';
    return 'produccion';
  }

  /**
   * «Verificar conexión y empresa»: solo GET al PSE. Contrasta RUC, entorno,
   * URLs y credenciales registradas contra la configuración local de la
   * empresa, sin escribir nada en el proveedor ni en la base.
   */
  async verificarEmpresaGre(ruc: string): Promise<GreEmpresaVerificacion> {
    const creds = await this.credentialsService.resolve();
    const rucNorm = String(ruc ?? '').trim();
    const problemas: string[] = [];

    const resultado: GreEmpresaVerificacion = {
      ruc: rucNorm,
      companyId: null,
      rucCoincide: false,
      entorno: null,
      entornoNombre: null,
      apiCpeUrl: null,
      urlsCoherentes: true,
      clientIdPse: null,
      clientIdLocal: creds.clientId || null,
      esCredencialPrueba: false,
      tieneSolLocal: Boolean(creds.solUser && creds.solPass),
      listo: false,
      problemas,
    };

    if (!creds.enabled) {
      problemas.push('La integración de facturación electrónica está deshabilitada');
      return resultado;
    }
    if (!creds.token && !(creds.username && creds.password)) {
      problemas.push('Configura token o usuario/clave del PSE en Configuración → SUNAT');
      return resultado;
    }
    if (creds.defaultRuc && creds.defaultRuc !== rucNorm) {
      problemas.push(`El RUC emisor configurado (${creds.defaultRuc}) no coincide con el de la empresa (${rucNorm})`);
    }

    const companyId = await this.resolveCompanyId(rucNorm, creds);
    if (companyId == null) {
      problemas.push(`El RUC ${rucNorm} no está registrado como empresa en el PSE`);
      return resultado;
    }
    resultado.companyId = companyId;
    resultado.rucCoincide = true;

    const empresa = (await this.obtenerEmpresa(companyId)) as EmpresaPse;
    const entornoNombre =
      typeof empresa.environment === 'string' ? empresa.environment : (empresa.environment?.nombre ?? null);
    const urls =
      typeof empresa.environment === 'object' && empresa.environment
        ? [empresa.environment.api_cpe_url, empresa.environment.auth_url].filter(Boolean)
        : [];
    resultado.entornoNombre = entornoNombre;
    resultado.entorno = this.normalizarEntorno(entornoNombre);
    resultado.apiCpeUrl =
      typeof empresa.environment === 'object' && empresa.environment
        ? (empresa.environment.api_cpe_url ?? null)
        : null;
    resultado.clientIdPse = String(empresa.client_id ?? '').trim() || null;

    // Lo que autentica ante SUNAT es el client_id que tiene la empresa en el
    // PSE, no el local: se evalúa ese.
    const clientIdEfectivo = resultado.clientIdPse ?? '';
    resultado.esCredencialPrueba = clientIdEfectivo.startsWith('test-');

    if (!resultado.entorno) {
      problemas.push('El PSE no informa el entorno de la empresa');
    } else if (resultado.entorno === 'beta') {
      if (urls.length > 0 && urls.some((url) => !GRE_TEST_URL.test(String(url)))) {
        resultado.urlsCoherentes = false;
        problemas.push('El entorno BETA tiene URLs GRE distintas del simulador esperado (gre-test.nubefact.com)');
      }
      if (!clientIdEfectivo) {
        problemas.push('La empresa BETA no tiene credenciales OAuth GRE en el PSE: usa «Sincronizar configuración GRE»');
      } else if (!resultado.esCredencialPrueba) {
        problemas.push('La empresa BETA tiene un client_id real; el simulador solo acepta el de prueba: usa «Sincronizar configuración GRE»');
      }
    } else {
      if (urls.some((url) => GRE_TEST_URL.test(String(url)))) {
        resultado.urlsCoherentes = false;
        problemas.push('La empresa está en PRODUCCIÓN pero apunta al simulador GRE de pruebas');
      }
      if (!creds.clientId || !creds.clientSecret) {
        problemas.push('Configura Client ID y Client Secret OAuth GRE reales en Configuración → SUNAT');
      } else if (creds.clientId.startsWith('test-')) {
        problemas.push('Las credenciales OAuth GRE locales son de prueba; en producción se requieren las generadas en SOL');
      }
      if (!clientIdEfectivo) {
        problemas.push('La empresa del PSE no tiene credenciales OAuth GRE: usa «Sincronizar configuración GRE»');
      } else if (resultado.esCredencialPrueba) {
        problemas.push('La empresa del PSE tiene el client_id de prueba; sincroniza las credenciales reales');
      } else if (creds.clientId && clientIdEfectivo !== creds.clientId) {
        problemas.push('El client_id GRE del PSE no coincide con el configurado localmente: usa «Sincronizar configuración GRE»');
      }
      if (!resultado.tieneSolLocal) {
        problemas.push('Registra usuario y clave SOL reales en Configuración → SUNAT antes de emitir en producción');
      } else if (String(empresa.sol_user ?? '').trim().toUpperCase() === GRE_TEST_SOL_USER) {
        problemas.push('La empresa del PSE conserva el usuario SOL de pruebas (MODDATOS); sincroniza las credenciales reales');
      }
    }

    resultado.listo = problemas.length === 0;
    return resultado;
  }

  /**
   * «Sincronizar configuración GRE»: la única operación que escribe en la
   * empresa del PSE. En BETA registra las credenciales públicas del simulador
   * (sin tocar los secretos reales guardados localmente); en producción envía
   * OAuth y SOL reales de la configuración de la empresa.
   */
  async sincronizarCredencialesGre(ruc: string): Promise<GreSincronizacionResultado> {
    const previo = await this.verificarEmpresaGre(ruc);
    if (previo.companyId == null || !previo.entorno) {
      return { ...previo, sincronizado: false, camposActualizados: [] };
    }

    const creds = await this.credentialsService.resolve();
    let cambios: Partial<FacturacionApisperuCompanyPayload>;
    if (previo.entorno === 'beta') {
      if (!previo.urlsCoherentes) {
        throw new BadRequestException('El entorno BETA tiene URLs GRE distintas del simulador esperado. Revisa el entorno en APIsPERU.');
      }
      cambios = {
        client_id: GRE_TEST_CLIENT_ID,
        client_secret: GRE_TEST_CLIENT_SECRET,
        sol_user: GRE_TEST_SOL_USER,
        sol_pass: GRE_TEST_SOL_USER,
      };
    } else {
      if (!creds.clientId || !creds.clientSecret) {
        throw new BadRequestException('Configura Client ID y Client Secret OAuth GRE en Configuración → SUNAT antes de sincronizar producción.');
      }
      if (creds.clientId.startsWith('test-')) {
        throw new BadRequestException('Las credenciales GRE de prueba solo pueden usarse en el entorno BETA.');
      }
      if (!creds.solUser || !creds.solPass) {
        throw new BadRequestException('Registra usuario y clave SOL reales en Configuración → SUNAT antes de sincronizar producción.');
      }
      cambios = {
        client_id: creds.clientId,
        client_secret: creds.clientSecret,
        sol_user: creds.solUser,
        sol_pass: creds.solPass,
      };
    }

    await this.actualizarEmpresa(previo.companyId, cambios);
    const posterior = await this.verificarEmpresaGre(ruc);
    return { ...posterior, sincronizado: true, camposActualizados: Object.keys(cambios) };
  }

  /** Consulta de ticket GRE: solo lectura, nunca modifica la empresa del PSE. */
  async consultarEstadoGuiaRemision(
    query: FacturacionResumenStatusQuery,
  ): Promise<FacturacionApisperuPayload> {
    return this.request<FacturacionApisperuPayload>(
      'GET',
      '/despatch/status',
      undefined,
      {
        params: await this.withDefaultRuc(query),
      },
    );
  }

  async enviarPercepcion(
    payload: FacturacionApisperuPayload,
  ): Promise<FacturacionApisperuDocumentResponse> {
    return this.request<FacturacionApisperuDocumentResponse>(
      'POST',
      '/perception/send',
      payload,
    );
  }

  async enviarRetencion(
    payload: FacturacionApisperuPayload,
  ): Promise<FacturacionApisperuDocumentResponse> {
    return this.request<FacturacionApisperuDocumentResponse>(
      'POST',
      '/retention/send',
      payload,
    );
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
        : undefined);

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
          : undefined);

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
    if (query.ruc) return { ...query };

    const creds = await this.credentialsService.resolve();
    if (!creds.defaultRuc) {
      return { ...query };
    }

    return { ...query, ruc: creds.defaultRuc };
  }

  private async resolveAuthToken(): Promise<string> {
    const creds = await this.credentialsService.resolve();
    if (creds.token) return creds.token;

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
        this.logger.error(
          `APIsPERU ${response.status} ${method} ${path}: ${this.safeJson(response.data)}`,
        );
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

      // El cuerpo de la respuesta se serializa a mano: pasarlo como segundo
      // argumento del logger lo imprime como "[object Object]" y ahí se pierde
      // justo el detalle que dice por qué el PSE rechazó el documento.
      this.logger.error(
        `Error APIsPERU ${method} ${path} (HTTP ${axiosError.response?.status ?? '—'}): ` +
          `${axiosError.message} | respuesta=${this.safeJson(axiosError.response?.data)}`,
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
      const detalle = this.extractProviderErrorDetail(obj);
      return detalle
        ? `${obj.message.trim()} — ${detalle}`
        : obj.message.trim();
    }
    return null;
  }

  /**
   * APIsPERU anida el motivo real ("errors", "detail", "sunatResponse") bajo un
   * mensaje genérico. Sin esto el usuario solo ve "error del servidor interno".
   */
  private extractProviderErrorDetail(
    obj: Record<string, unknown>,
  ): string | null {
    for (const clave of [
      'detail',
      'details',
      'errors',
      'error_description',
      'sunatResponse',
    ]) {
      const valor = obj[clave];
      if (!valor) continue;
      if (typeof valor === 'string' && valor.trim()) return valor.trim();
      if (typeof valor === 'object') return this.safeJson(valor);
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
          obj.payload != null
            ? ` | ${this.safeJson(obj.payload).slice(0, 400)}`
            : '';
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
          // err.code llega como unknown: solo se antepone si es escalar, para no
          // terminar imprimiendo "[object Object]" delante del mensaje.
          const code =
            typeof err.code === 'string' || typeof err.code === 'number'
              ? `[${err.code}] `
              : '';
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
