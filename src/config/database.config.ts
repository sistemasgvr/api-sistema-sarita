import { registerAs } from '@nestjs/config';

export default registerAs('database', () => ({
  url: process.env.DATABASE_URL,
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT ?? 5432),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD ?? '',
  database: process.env.DB_NAME,
  ssl:
    process.env.DB_SSL === 'true' ||
    process.env.DATABASE_URL?.includes('sslmode=require') ||
    false,
  poolMax: Number(process.env.DB_POOL_MAX ?? 10),
  idleTimeoutMillis: Number(process.env.DB_IDLE_TIMEOUT_MS ?? 30_000),
  connectionTimeoutMillis: Number(process.env.DB_CONNECTION_TIMEOUT_MS ?? 10_000),
}));
