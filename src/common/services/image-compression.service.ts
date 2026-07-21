import { Injectable, Logger } from '@nestjs/common';
import sharp from 'sharp';

export interface CompressedImageResult {
  buffer: Buffer;
  mimeType: string;
  extension: string;
  originalBytes: number;
  compressedBytes: number;
  compressed: boolean;
}

const IMAGE_MIME_TYPES = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/avif',
]);

const IMAGE_EXTENSIONS = new Set([
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'avif',
]);

@Injectable()
export class ImageCompressionService {
  private readonly logger = new Logger(ImageCompressionService.name);

  isImage(mimeType?: string | null, filename?: string | null): boolean {
    const mime = (mimeType ?? '').toLowerCase().trim();
    if (IMAGE_MIME_TYPES.has(mime)) return true;

    const ext = this.extensionFromName(filename);
    return ext != null && IMAGE_EXTENSIONS.has(ext);
  }

  async compressMulterFile(
    file: Express.Multer.File,
  ): Promise<Express.Multer.File> {
    if (!file?.buffer?.length || !this.isImage(file.mimetype, file.originalname)) {
      return file;
    }

    const result = await this.compress(file.buffer, file.mimetype, file.originalname);
    if (!result.compressed) {
      return file;
    }

    return {
      ...file,
      buffer: result.buffer,
      size: result.compressedBytes,
      mimetype: result.mimeType,
    };
  }

  async compress(
    input: Buffer,
    mimeType?: string | null,
    filename?: string | null,
  ): Promise<CompressedImageResult> {
    const originalBytes = input.length;
    const format = this.resolveFormat(mimeType, filename);

    try {
      const pipeline = sharp(input, {
        animated: format === 'gif',
        failOn: 'none',
      }).rotate();

      let output: Buffer;
      let outMime: string;
      let outExt: string;

      switch (format) {
        case 'png':
          // Compresión lossless (sin pérdida visual)
          output = await pipeline
            .png({ compressionLevel: 9, effort: 7, palette: false })
            .toBuffer();
          outMime = 'image/png';
          outExt = 'png';
          break;
        case 'webp':
          // nearLossless ≈ calidad visual casi intacta con menos peso
          output = await pipeline
            .webp({ quality: 90, nearLossless: true, effort: 5 })
            .toBuffer();
          outMime = 'image/webp';
          outExt = 'webp';
          break;
        case 'gif':
          output = await pipeline.gif({ effort: 7 }).toBuffer();
          outMime = 'image/gif';
          outExt = 'gif';
          break;
        case 'avif':
          output = await pipeline
            .avif({ quality: 70, effort: 4 })
            .toBuffer();
          outMime = 'image/avif';
          outExt = 'avif';
          break;
        case 'jpeg':
        default:
          // Calidad alta (90) + mozjpeg para mejor ratio sin pérdida perceptible
          output = await pipeline
            .jpeg({ quality: 90, mozjpeg: true, chromaSubsampling: '4:4:4' })
            .toBuffer();
          outMime = 'image/jpeg';
          outExt = 'jpg';
          break;
      }

      // Solo usar el resultado si realmente ahorra espacio
      if (output.length >= originalBytes) {
        this.logger.debug(
          `Imagen sin ganancia de compresión (${originalBytes} -> ${output.length} bytes)`,
        );
        return {
          buffer: input,
          mimeType: mimeType || outMime,
          extension: this.extensionFromName(filename) || outExt,
          originalBytes,
          compressedBytes: originalBytes,
          compressed: false,
        };
      }

      this.logger.log(
        `Imagen comprimida: ${originalBytes} -> ${output.length} bytes (${Math.round((1 - output.length / originalBytes) * 100)}%)`,
      );

      return {
        buffer: output,
        mimeType: outMime,
        extension: outExt,
        originalBytes,
        compressedBytes: output.length,
        compressed: true,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`No se pudo comprimir imagen, se sube original: ${message}`);
      return {
        buffer: input,
        mimeType: mimeType || 'application/octet-stream',
        extension: this.extensionFromName(filename) || 'bin',
        originalBytes,
        compressedBytes: originalBytes,
        compressed: false,
      };
    }
  }

  private resolveFormat(
    mimeType?: string | null,
    filename?: string | null,
  ): 'jpeg' | 'png' | 'webp' | 'gif' | 'avif' {
    const mime = (mimeType ?? '').toLowerCase();
    if (mime.includes('png')) return 'png';
    if (mime.includes('webp')) return 'webp';
    if (mime.includes('gif')) return 'gif';
    if (mime.includes('avif')) return 'avif';
    if (mime.includes('jpeg') || mime.includes('jpg')) return 'jpeg';

    const ext = this.extensionFromName(filename);
    if (ext === 'png') return 'png';
    if (ext === 'webp') return 'webp';
    if (ext === 'gif') return 'gif';
    if (ext === 'avif') return 'avif';
    return 'jpeg';
  }

  private extensionFromName(filename?: string | null): string | null {
    if (!filename) return null;
    const idx = filename.lastIndexOf('.');
    if (idx <= 0 || idx === filename.length - 1) return null;
    return filename.slice(idx + 1).toLowerCase();
  }
}
