import { BadRequestException } from '@nestjs/common';

/** Solo identificadores: no aplicar a nombres, direcciones, claves ni tokens. */
export function normalizarCodigoSunat(value?: string | null): string {
  return (value ?? '').trim().toUpperCase();
}

/** Conserva ceros iniciales. No elimina puntuación que podría cambiar el documento. */
export function normalizarDocumentoSunat(value?: string | null): string {
  return normalizarCodigoSunat(value).replace(/\s/g, '');
}

export function tipoDocumentoSunat(tipo?: string | null, numero?: string): string {
  const label = normalizarCodigoSunat(tipo).normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  // El tipo registrado tiene prioridad sobre la longitud (CE/pasaporte pueden tener 8 dígitos).
  if (['0', '1', '4', '6', '7'].includes(label)) return label;
  if (label.includes('RUC')) return '6';
  if (label.includes('DNI') || label.includes('DOCUMENTO NACIONAL')) return '1';
  if (label === 'CE' || label === 'C.E.' || label.includes('EXTRANJER')) return '4';
  if (label.includes('PAS')) return '7';
  const doc = normalizarDocumentoSunat(numero);
  if (/^\d{11}$/.test(doc)) return '6';
  if (/^\d{8}$/.test(doc)) return '1';
  throw new BadRequestException('Selecciona el tipo de documento: no se puede deducir del número registrado.');
}

export function documentoSunatValido(numero: string, tipo: string): boolean {
  if (tipo === '6') return /^\d{11}$/.test(numero);
  if (tipo === '1') return /^\d{8}$/.test(numero);
  return /^[A-Z0-9]{1,15}$/.test(numero);
}

export function receptorSunat(tipo?: string | null, numero?: string | null) {
  const numDoc = normalizarDocumentoSunat(numero);
  const tipoDoc = tipoDocumentoSunat(tipo, numDoc);
  if (!documentoSunatValido(numDoc, tipoDoc)) {
    throw new BadRequestException('El número de documento no corresponde al tipo registrado. Revisa ambos datos antes de enviar.');
  }
  return { tipoDoc, numDoc };
}

export function rucSunat(numero: string): string {
  const ruc = normalizarDocumentoSunat(numero);
  if (!documentoSunatValido(ruc, '6')) throw new BadRequestException('El RUC de la empresa emisora debe tener 11 dígitos. Revisa Configuración → Empresa.');
  return ruc;
}

/** Fecha civil: no cambia el día según la zona del proceso ni acepta fechas inexistentes. */
export function fechaCivilSunat(value?: string | null): string | null {
  const raw = (value ?? '').trim();
  if (!/^\d{4}-\d{2}-\d{2}(?:$|T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?$)/.test(raw)) return null;
  const base = raw.slice(0, 10);
  const date = new Date(`${base}T00:00:00Z`);
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== base) return null;
  if (raw.length > 10 && !Number.isFinite(Date.parse(raw))) return null;
  return base;
}

export function fechaHoraSunat(value?: string | null): string {
  const base = fechaCivilSunat(value);
  if (!base) throw new BadRequestException('La fecha debe ser válida y estar en formato AAAA-MM-DD. Revisa la fecha antes de enviar.');
  return `${base}T00:00:00-05:00`;
}

export function correlativoSunat(value: string): string {
  const raw = value.trim();
  if (!/^\d+$/.test(raw) || !Number.isSafeInteger(Number(raw)) || Number(raw) < 1) {
    throw new BadRequestException('El correlativo debe ser un número entero mayor a cero, sin letras ni separadores.');
  }
  return raw.replace(/^0+/, '');
}
