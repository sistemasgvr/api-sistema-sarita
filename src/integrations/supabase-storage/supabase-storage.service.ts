import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type {
  SupabaseListItem,
  SupabaseSignedUrlResult,
  SupabaseUploadResult,
} from './interfaces/supabase-storage.interface';

@Injectable()
export class SupabaseStorageService {
  private readonly logger = new Logger(SupabaseStorageService.name);
  private readonly client: SupabaseClient | null;
  private readonly bucket: string;

  constructor(private readonly config: ConfigService) {
    const url = this.config.get<string>('supabase.url')?.trim() ?? '';
    const serviceRoleKey =
      this.config.get<string>('supabase.serviceRoleKey')?.trim() ?? '';
    this.bucket =
      this.config.get<string>('supabase.storageBucket')?.trim() ||
      'storage-sarita';

    if (!url || !serviceRoleKey) {
      this.client = null;
      this.logger.warn(
        'Supabase Storage no configurado (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)',
      );
      return;
    }

    this.client = createClient(url, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });
  }

  isConfigured(): boolean {
    return this.client != null;
  }

  getBucket(): string {
    return this.bucket;
  }

  private requireClient(): SupabaseClient {
    if (!this.client) {
      throw new ServiceUnavailableException(
        'Supabase Storage no está configurado. Define SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY.',
      );
    }
    return this.client;
  }

  async ping(): Promise<{ bucket: string; ok: boolean; message: string }> {
    const client = this.requireClient();
    const { error } = await client.storage.from(this.bucket).list('', {
      limit: 1,
    });

    if (error) {
      this.logger.error(`Supabase Storage ping falló: ${error.message}`);
      throw new ServiceUnavailableException(
        `No se pudo acceder al bucket "${this.bucket}": ${error.message}`,
      );
    }

    return {
      bucket: this.bucket,
      ok: true,
      message: 'Conexión a Supabase Storage OK',
    };
  }

  async list(
    folder = '',
    limit = 100,
  ): Promise<SupabaseListItem[]> {
    const client = this.requireClient();
    const { data, error } = await client.storage
      .from(this.bucket)
      .list(folder, { limit, sortBy: { column: 'name', order: 'asc' } });

    if (error) {
      throw new BadRequestException(
        `Error al listar archivos: ${error.message}`,
      );
    }

    return (data ?? []).map((item) => ({
      name: item.name,
      id: item.id,
      updatedAt: item.updated_at,
      createdAt: item.created_at,
      lastAccessedAt: item.last_accessed_at,
      metadata: (item.metadata as Record<string, unknown> | null) ?? null,
    }));
  }

  async upload(
    path: string,
    body: Buffer | Uint8Array | ArrayBuffer | Blob | File,
    contentType?: string,
    upsert = true,
  ): Promise<SupabaseUploadResult> {
    const client = this.requireClient();
    const cleanPath = path.replace(/^\/+/, '');

    if (!cleanPath) {
      throw new BadRequestException('La ruta del archivo es obligatoria');
    }

    const { data, error } = await client.storage
      .from(this.bucket)
      .upload(cleanPath, body, {
        contentType,
        upsert,
      });

    if (error) {
      throw new BadRequestException(
        `Error al subir archivo: ${error.message}`,
      );
    }

    return {
      path: data.path,
      bucket: this.bucket,
      fullPath: data.fullPath,
    };
  }

  async createSignedUrl(
    path: string,
    expiresInSeconds = 3600,
  ): Promise<SupabaseSignedUrlResult> {
    const client = this.requireClient();
    const cleanPath = path.replace(/^\/+/, '');

    const { data, error } = await client.storage
      .from(this.bucket)
      .createSignedUrl(cleanPath, expiresInSeconds);

    if (error || !data?.signedUrl) {
      throw new BadRequestException(
        `Error al generar URL firmada: ${error?.message ?? 'sin URL'}`,
      );
    }

    return {
      path: cleanPath,
      signedUrl: data.signedUrl,
      expiresIn: expiresInSeconds,
    };
  }

  async remove(paths: string[]): Promise<void> {
    const client = this.requireClient();
    const cleanPaths = paths.map((p) => p.replace(/^\/+/, '')).filter(Boolean);

    if (!cleanPaths.length) {
      throw new BadRequestException('Indica al menos una ruta a eliminar');
    }

    const { error } = await client.storage.from(this.bucket).remove(cleanPaths);

    if (error) {
      throw new BadRequestException(
        `Error al eliminar archivos: ${error.message}`,
      );
    }
  }
}
