import { BadRequestException } from '@nestjs/common';

/** Acepta el XML original del envío, en texto o en base64. No lo regenera. */
export function xmlGreBuffer(value: unknown): Buffer | null {
  if (typeof value !== 'string' || !value.trim()) return null;
  const text = value.trim();
  const buffer = text.startsWith('<') ? Buffer.from(value, 'utf8') : Buffer.from(text, 'base64');
  const xml = buffer.toString('utf8').replace(/^\uFEFF/, '').trimStart();
  if (!/^(?:<\?xml[^>]*>\s*)?<(?:[\w.-]+:)?DespatchAdvice\b/.test(xml) || /<!DOCTYPE/i.test(xml)) {
    throw new BadRequestException('El XML guardado no es una guía de remisión válida');
  }
  return buffer;
}

export function pdfGreBuffer(value: string): Buffer {
  const buffer = Buffer.from(value, 'base64');
  if (buffer.subarray(0, 5).toString('ascii') !== '%PDF-') {
    throw new BadRequestException('El proveedor no devolvió un PDF válido');
  }
  return buffer;
}
