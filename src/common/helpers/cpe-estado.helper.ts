import { inflateRawSync } from 'node:zlib';

export type EstadoCpe = 'ACEPTADO' | 'RECHAZADO' | 'PENDIENTE';

/** Error explícito de la petición al proveedor; un timeout sigue siendo incierto. */
export function esErrorEnvioCpe(payload: unknown): boolean {
  const root = (payload ?? {}) as Record<string, any>;
  const data = root.sunatResponse ?? root;
  return data.success === false && data.error?.code === 'HTTP' && !data.cdrResponse && !data.ticket;
}

/** success indica éxito de la operación; el CDR determina la aceptación. */
export function estadoDesdeCdr(payload: unknown): EstadoCpe {
  const root = (payload ?? {}) as Record<string, any>;
  const data = root.sunatResponse ?? root;
  const cdr = data.cdrResponse;
  const raw = cdr?.code;
  if (raw != null && String(raw).trim() !== '') {
    const code = Number(raw);
    if (code === 0) return 'ACEPTADO';
    if (code === 99 || (code >= 2000 && code <= 3999)) return 'RECHAZADO';
    return 'PENDIENTE';
  }
  if (cdr?.accepted === true) return 'ACEPTADO';
  if (cdr?.accepted === false) return 'RECHAZADO';
  const errorCode = Number(data.error?.code);
  if (errorCode >= 2000 && errorCode <= 3999) return 'RECHAZADO';
  return 'PENDIENTE';
}

/** Una consulta por serie/número puede devolver una constancia histórica. */
export function cdrCorrespondeAlDocumento(payload: unknown, serie: string, numero: string, fecha: string, codigoEsperado?: string): boolean {
  const root = (payload ?? {}) as Record<string, any>;
  const data = root.sunatResponse ?? root;
  if (typeof data.cdrZip !== 'string' || data.cdrZip.length > 2_000_000) return false;
  try {
    const zip = Buffer.from(data.cdrZip, 'base64');
    for (let i = 0; i + 46 <= zip.length; i++) {
      if (zip.readUInt32LE(i) !== 0x02014b50) continue;
      const size = zip.readUInt32LE(i + 20);
      const nameLength = zip.readUInt16LE(i + 28);
      if (!/\.xml$/i.test(zip.subarray(i + 46, i + 46 + nameLength).toString())) continue;
      const offset = zip.readUInt32LE(i + 42);
      const start = offset + 30 + zip.readUInt16LE(offset + 26) + zip.readUInt16LE(offset + 28);
      if (start + size > zip.length) return false;
      const bytes = zip.subarray(start, start + size);
      const xml = zip.readUInt16LE(offset + 8) === 0 ? bytes.toString() : inflateRawSync(bytes, { maxOutputLength: 1_000_000 }).toString();
      const reference = xml.match(/<cbc:ReferenceID[^>]*>([^<]+)<\/cbc:ReferenceID>/)?.[1];
      const date = xml.match(/<cbc:ResponseDate[^>]*>(\d{4}-\d{2}-\d{2})/)?.[1];
      const code = xml.match(/<cbc:ResponseCode[^>]*>([^<]+)<\/cbc:ResponseCode>/)?.[1]?.trim();
      const expected = `${serie}-${numero.replace(/^0+/, '') || '0'}`;
      const normalized = reference?.replace(/-(0+)(\d+)$/, '-$2');
      return normalized === expected && !!date && date >= fecha.slice(0, 10) && (codigoEsperado == null || code === codigoEsperado);
    }
  } catch { return false; }
  return false;
}

export function mensajeErrorCpe(value: string): string {
  if (/timeout|timed out|curl error 28|ECONNABORTED|ETIMEDOUT/i.test(value)) {
    return 'APIs Perú agotó el tiempo de espera de emisión. El resultado está por confirmar; consulta la validez del comprobante antes de volver a emitir.';
  }
  return value
    .replace(/([?&](?:token|access_token|client_secret)=)[^\s&"'<>]+/gi, '$1[OCULTO]')
    .replace(/(Bearer\s+)[\w.\-]+/gi, '$1[OCULTO]');
}
