import {
  Injectable,
  Logger,
  OnModuleDestroy,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool, PoolClient, PoolConfig, QueryResult, QueryResultRow } from 'pg';

@Injectable()
export class DatabaseService implements OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);
  private readonly pool: Pool;

  constructor(private readonly configService: ConfigService) {
    this.pool = this.createPool();

    // Obligatorio con pg: evita que errores en clientes idle derriben el proceso.
    this.pool.on('error', (error) => {
      this.logger.error(
        `Error en conexión idle del pool PostgreSQL: ${error.message}`,
        error.stack,
      );
    });
  }

  private createPool(): Pool {
    const ssl = this.configService.get<boolean>('database.ssl');
    const sslConfig = ssl ? { rejectUnauthorized: false } : undefined;

    const poolConfig: PoolConfig = {
      max: this.configService.get<number>('database.poolMax') ?? 10,
      idleTimeoutMillis:
        this.configService.get<number>('database.idleTimeoutMillis') ?? 30_000,
      connectionTimeoutMillis:
        this.configService.get<number>('database.connectionTimeoutMillis') ??
        10_000,
      keepAlive: true,
      ssl: sslConfig,
    };

    const databaseUrl = this.configService.get<string>('database.url');

    if (databaseUrl) {
      poolConfig.connectionString = databaseUrl;
    } else {
      poolConfig.host = this.configService.get<string>('database.host');
      poolConfig.port = this.configService.get<number>('database.port');
      poolConfig.user = this.configService.get<string>('database.user');
      poolConfig.password = this.configService.get<string>('database.password');
      poolConfig.database = this.configService.get<string>('database.database');
    }

    return new Pool(poolConfig);
  }

  async onModuleDestroy() {
    await this.pool.end();
  }

  async checkConnection(): Promise<boolean> {
    try {
      await this.pool.query('SELECT 1');
      return true;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`No se pudo conectar a PostgreSQL: ${message}`);
      return false;
    }
  }

  getConnectionInfo() {
    const databaseUrl = this.configService.get<string>('database.url');

    if (databaseUrl) {
      try {
        const parsed = new URL(databaseUrl);
        return {
          host: parsed.hostname,
          port: Number(parsed.port || 5432),
          database: parsed.pathname.replace(/^\//, ''),
          user: decodeURIComponent(parsed.username),
        };
      } catch {
        return {
          host: 'DATABASE_URL',
          port: 5432,
          database: '—',
          user: '—',
        };
      }
    }

    return {
      host: this.configService.get<string>('database.host') ?? '—',
      port: this.configService.get<number>('database.port') ?? 5432,
      database: this.configService.get<string>('database.database') ?? '—',
      user: this.configService.get<string>('database.user') ?? '—',
    };
  }

  async query<T extends QueryResultRow = QueryResultRow>(
    sql: string,
    params?: unknown[],
  ): Promise<QueryResult<T>> {
    return this.pool.query<T>(sql, params);
  }

  async callFunction<T extends QueryResultRow = QueryResultRow>(
    functionName: string,
    params: unknown[] = [],
  ): Promise<T[]> {
    const placeholders = params.map((_, i) => `$${i + 1}`).join(', ');
    const sql = `SELECT * FROM ${functionName}(${placeholders})`;
    const result = await this.query<T>(sql, params);
    return result.rows;
  }

  async callFunctionJson<T = unknown>(
    functionName: string,
    params: unknown[] = [],
  ): Promise<T> {
    const placeholders = params.map((_, i) => `$${i + 1}`).join(', ');
    const sql = `SELECT ${functionName}(${placeholders}) AS result`;
    const result = await this.query<{ result: T }>(sql, params);
    return result.rows[0]?.result ?? (null as T);
  }

  async getClient(): Promise<PoolClient> {
    return this.pool.connect();
  }
}
