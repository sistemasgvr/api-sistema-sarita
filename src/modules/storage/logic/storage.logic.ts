import { BadRequestException, Injectable } from '@nestjs/common';
import { ImageCompressionService } from '../../../common/services/image-compression.service';
import { SupabaseStorageService } from '../../../integrations/supabase-storage/supabase-storage.service';
import { ArchivosLogic } from '../../archivos/logic/archivos.logic';

@Injectable()
export class StorageLogic {
  constructor(
    private readonly supabaseStorage: SupabaseStorageService,
    private readonly archivosLogic: ArchivosLogic,
    private readonly imageCompression: ImageCompressionService,
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

    const fileToUpload = await this.imageCompression.compressMulterFile(file);
    const cleanPath = this.ajustarExtensionSiCorresponde(
      path.trim().replace(/^\/+/, ''),
      file,
      fileToUpload,
    );

    const uploaded = await this.supabaseStorage.upload(
      cleanPath,
      fileToUpload.buffer,
      fileToUpload.mimetype,
      upsert,
    );

    const nombreAlmacenado =
      cleanPath.split('/').filter(Boolean).pop() || cleanPath;
    const nombreOriginal = file.originalname?.trim() || nombreAlmacenado;
    const extension = this.extraerExtension(nombreAlmacenado);

    const archivo = await this.archivosLogic.crear({
      nombreOriginal,
      nombreAlmacenado,
      ruta: uploaded.path,
      bucket: uploaded.bucket,
      mimeType: fileToUpload.mimetype || undefined,
      extension: extension || undefined,
      tamanioBytes: fileToUpload.size,
      idEmpresa,
      idUsuarioAuditoria,
    });

    return {
      ...uploaded,
      archivo,
      compression:
        fileToUpload.size !== file.size
          ? {
              originalBytes: file.size,
              compressedBytes: fileToUpload.size,
              savedBytes: file.size - fileToUpload.size,
            }
          : null,
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

  private ajustarExtensionSiCorresponde(
    path: string,
    original: Express.Multer.File,
    compressed: Express.Multer.File,
  ): string {
    if (original.mimetype === compressed.mimetype) return path;

    const newExt = this.extraerExtensionFromMime(compressed.mimetype);
    if (!newExt) return path;

    const lastSlash = path.lastIndexOf('/');
    const dir = lastSlash >= 0 ? path.slice(0, lastSlash + 1) : '';
    const filename = lastSlash >= 0 ? path.slice(lastSlash + 1) : path;
    const dot = filename.lastIndexOf('.');
    const base = dot > 0 ? filename.slice(0, dot) : filename;
    return `${dir}${base}.${newExt}`;
  }

  private extraerExtensionFromMime(mime?: string): string | null {
    switch ((mime ?? '').toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/avif':
        return 'avif';
      default:
        return null;
    }
  }

  private extraerExtension(nombre: string): string | null {
    const idx = nombre.lastIndexOf('.');
    if (idx <= 0 || idx === nombre.length - 1) return null;
    return nombre.slice(idx + 1).toLowerCase().slice(0, 20);
  }
}
