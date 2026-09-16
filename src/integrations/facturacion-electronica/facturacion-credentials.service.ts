import { AsyncLocalStorage } from 'node:async_hooks';
import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../../database/database.service';

/** Credenciales genéricas de facturación electrónica (PSE/OSE). */
export interface FacturacionCredentials {
  enabled: boolean;
  provider: string | null;
  baseUrl: string;
  token: string;
  username: string;
  password: string;
  defaultRuc: string;
  clientId: string;
  clientSecret: string;
  /** Usuario/clave SOL de la empresa (solo BD); en producción el PSE los exige. */
  solUser: string;
  solPass: string;
  timeoutMs: number;
  source: 'database' | 'env' | 'mixed';
}

interface CredencialesDbRow {
  proveedor_pse?: string | null;
  pse_habilitado?: boolean | null;
  api_base_url?: string | null;
  api_token?: string | null;
  api_usuario?: string | null;
  api_clave?: string | null;
  ruc_emisor?: string | null;
  ruc_empresa?: string | null;
  client_id?: string | null;
  client_secret?: string | null;
  usuario_sol?: string | null;
  clave_sol?: string | null;
  timeout_ms?: number | null;
}

/**
 * Resuelve credenciales PSE: prioriza configuración SUNAT (BD),
 * con fallback a variables de entorno (migración / emergencia).
 */
@Injectable()
export class FacturacionCredentialsService {
  private readonly logger = new Logger(FacturacionCredentialsService.name);
  private readonly empresaContext = new AsyncLocalStorage<number>();

  withEmpresa<T>(idEmpresa: number, operation: () => Promise<T>): Promise<T> {
    return this.empresaContext.run(idEmpresa, operation);
  }

  private cache: FacturacionCredentials | null = null;
  private cacheAt = 0;
  private readonly ttlMs = 15_000;

  constructor(
    private readonly db: DatabaseService,
    private readonly configService: ConfigService,
  ) {}

  invalidate(): void {
    this.cache = null;
    this.cacheAt = 0;
  }

  async resolve(): Promise<FacturacionCredentials> {
    const idEmpresa = this.empresaContext.getStore();
    if (idEmpresa != null) {
      const result = await this.db.query<CredencialesDbRow>(
        `SELECT cs.*, e.ruc AS ruc_empresa FROM gen_configuracion_sunat cs
         JOIN gen_empresa e ON e.id = cs.id_empresa AND e.estado = 1
         WHERE cs.estado = 1 AND cs.id_empresa = $1`, [idEmpresa],
      );
      if (result.rows.length !== 1) {
        throw new BadRequestException('La empresa emisora debe tener una única configuración SUNAT activa');
      }
      const row = result.rows[0];
      if (row.ruc_emisor?.trim() && row.ruc_emisor.trim() !== row.ruc_empresa?.trim()) {
        throw new BadRequestException('El RUC emisor SUNAT no coincide con la empresa de la guía');
      }
      // Nunca completar secretos con credenciales de otra empresa o del entorno.
      return this.merge({ ...row, ruc_emisor: row.ruc_empresa }, {
        enabled: false, provider: null, baseUrl: '', token: '', username: '', password: '',
        defaultRuc: '', clientId: '', clientSecret: '', solUser: '', solPass: '', timeoutMs: 60000, source: 'database',
      });
    }
    if (this.cache && Date.now() - this.cacheAt < this.ttlMs) {
      return this.cache;
    }

    const env = this.fromEnv();
    let dbRow: CredencialesDbRow | null = null;

    try {
      const result = await this.db.callFunctionJson<{
        registro?: CredencialesDbRow | null;
      }>('gen_obtener_credenciales_facturacion', []);
      dbRow = result.registro ?? null;
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(
        `No se pudo leer credenciales de configuración SUNAT (usando .env): ${message}`,
      );
    }

    const merged = this.merge(dbRow, env);
    this.cache = merged;
    this.cacheAt = Date.now();
    return merged;
  }

  private fromEnv(): FacturacionCredentials {
    return {
      enabled: this.configService.get<boolean>('facturacion.enabled') !== false,
      provider: 'ENV',
      baseUrl: (
        this.configService.get<string>('facturacion.baseUrl') ??
        'https://facturacion.apisperu.com/api/v1'
      ).replace(/\/$/, ''),
      token: (this.configService.get<string>('facturacion.token') ?? '').trim(),
      username: (
        this.configService.get<string>('facturacion.username') ?? ''
      ).trim(),
      password: (
        this.configService.get<string>('facturacion.password') ?? ''
      ).trim(),
      defaultRuc: (
        this.configService.get<string>('facturacion.defaultRuc') ?? ''
      ).trim(),
      clientId: (
        this.configService.get<string>('facturacion.clientId') ?? ''
      ).trim(),
      clientSecret: (
        this.configService.get<string>('facturacion.clientSecret') ?? ''
      ).trim(),
      solUser: '',
      solPass: '',
      timeoutMs: this.configService.get<number>('facturacion.timeoutMs') ?? 60_000,
      source: 'env',
    };
  }

  private merge(
    db: CredencialesDbRow | null,
    env: FacturacionCredentials,
  ): FacturacionCredentials {
    if (!db) return env;

    const pick = (dbValue?: string | null, envValue = '') => {
      const trimmed = (dbValue ?? '').trim();
      return trimmed || envValue;
    };

    const hasDbSecret =
      Boolean((db.api_token ?? '').trim()) ||
      Boolean((db.api_usuario ?? '').trim()) ||
      Boolean((db.client_id ?? '').trim()) ||
      Boolean((db.api_base_url ?? '').trim());

    return {
      enabled:
        db.pse_habilitado == null
          ? env.enabled
          : Boolean(db.pse_habilitado),
      provider: pick(db.proveedor_pse, env.provider ?? '') || null,
      baseUrl: pick(db.api_base_url, env.baseUrl).replace(/\/$/, ''),
      token: pick(db.api_token, env.token),
      username: pick(db.api_usuario, env.username),
      password: pick(db.api_clave, env.password),
      defaultRuc: pick(db.ruc_emisor ?? db.ruc_empresa, env.defaultRuc),
      clientId: pick(db.client_id, env.clientId),
      clientSecret: pick(db.client_secret, env.clientSecret),
      solUser: pick(db.usuario_sol),
      solPass: pick(db.clave_sol),
      timeoutMs:
        db.timeout_ms != null && Number(db.timeout_ms) > 0
          ? Number(db.timeout_ms)
          : env.timeoutMs,
      source: hasDbSecret ? (env.token || env.clientId ? 'mixed' : 'database') : 'env',
    };
  }
}
