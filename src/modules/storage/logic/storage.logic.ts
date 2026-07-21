import { BadRequestException, Injectable } from '@nestjs/common';
import { SupabaseStorageService } from '../../../integrations/supabase-storage/supabase-storage.service';
import { ArchivosLogic } from '../../archivos/logic/archivos.logic';

@Injectable()
export class StorageLogic {
  constructor(
    private readonly supabaseStorage: SupabaseStorageService,
    private readonly archivosLogic: ArchivosLogic,
  ) {}

  status() {
    return {
      configured: this.supabaseStorage.isConfigured(),
      bucket: this.supabaseStorage.getBucket(),
    };
  }

  ping() {
    return this.supabaseStorage.ping();
  }

  listar(folder?: string) {
    return this.supabaseStorage.list(folder ?? '');
  }

  async subir(
    path: string,
    file: Express.Multer.File | undefined,
    upsert = true,
    idEmpresa?: number,
    idUsuarioAuditoria?: number,
  ) {
    if (!file?.buffer?.length) {
      throw new BadRequestException('Debes enviar un archivo en el campo "file"');
    }
    if (!path?.trim()) {
      throw new BadRequestException('Debes indicar la ruta destino en "path"');
    }

    const cleanPath = path.trim().replace(/^\/+/, '');
    const uploaded = await this.supabaseStorage.upload(
      cleanPath,
      file.buffer,
      file.mimetype,
      upsert,
    );

    const nombreAlmacenado =
      cleanPath.split('/').filter(Boolean).pop() || cleanPath;
    const nombreOriginal = file.originalname?.trim() || nombreAlmacenado;
    const extension = this.extraerExtension(nombreOriginal);

    const archivo = await this.archivosLogic.crear({
      nombreOriginal,
      nombreAlmacenado,
      ruta: uploaded.path,
      bucket: uploaded.bucket,
      mimeType: file.mimetype || undefined,
      extension: extension || undefined,
      tamanioBytes: file.size,
      idEmpresa,
      idUsuarioAuditoria,
    });

    return {
      ...uploaded,
      archivo,
    };
  }

  async firmarUrl(path: string, expiresInSeconds?: number) {
    return this.supabaseStorage.createSignedUrl(path, expiresInSeconds);
  }

  async firmarUrlPorId(idArchivo: number, expiresInSeconds?: number) {
    const archivo = (await this.archivosLogic.obtenerPorId(idArchivo)) as {
      ruta: string;
    };
    return this.supabaseStorage.createSignedUrl(
      archivo.ruta,
      expiresInSeconds,
    );
  }

  async eliminar(paths: string[], idUsuarioAuditoria?: number) {
    const bucket = this.supabaseStorage.getBucket();
    await this.supabaseStorage.remove(paths);

    for (const path of paths ?? []) {
      const cleanPath = path?.replace(/^\/+/, '');
      if (!cleanPath) continue;
      await this.archivosLogic.eliminarPorRuta(
        bucket,
        cleanPath,
        idUsuarioAuditoria,
      );
    }

    return { eliminado: true, paths };
  }

  private extraerExtension(nombre: string): string | null {
    const idx = nombre.lastIndexOf('.');
    if (idx <= 0 || idx === nombre.length - 1) return null;
    return nombre.slice(idx + 1).toLowerCase().slice(0, 20);
  }
}
