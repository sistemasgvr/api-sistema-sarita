const STOP_WORDS = new Set([
  'DE',
  'DEL',
  'LA',
  'EL',
  'LOS',
  'LAS',
  'Y',
  'O',
  'U',
  'PARA',
  'CON',
  'EN',
  'UN',
  'UNA',
  'UNOS',
  'UNAS',
  'AL',
  'POR',
  'THE',
  'OF',
  'A',
  'AND',
]);

function normalizeToken(value: string): string {
  return value
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, ' ')
    .trim();
}

function significantWords(text: string): string[] {
  return normalizeToken(text)
    .split(/\s+/)
    .filter((word) => word.length > 0)
    .filter((word) => !STOP_WORDS.has(word))
    // Omite códigos/números (ej. CGA540, 10M3)
    .filter((word) => !/\d/.test(word));
}

/** Iniciales del nombre (máx. 4 letras significativas). */
export function initialsFromNombre(nombre: string, maxLetters = 4): string {
  const words = significantWords(nombre);
  if (!words.length) return 'PROD';

  const initials = words
    .map((word) => word[0] ?? '')
    .join('')
    .slice(0, maxLetters);

  if (initials.length >= 2) return initials;

  return words[0].slice(0, Math.min(3, words[0].length));
}

/** Código corto de marca (máx. 3 caracteres). */
export function codeFromMarca(marca?: string | null): string {
  if (!marca?.trim()) return '';
  return normalizeToken(marca).replace(/\s+/g, '').slice(0, 3);
}

/**
 * Prefijo profesional: NOMBRE-MARCA (ej. ARO-GEN).
 * Si no hay marca: solo iniciales del nombre.
 */
export function buildCodigoUbicacionPrefijo(
  nombre: string,
  marca?: string | null,
): string {
  const nombrePart = initialsFromNombre(nombre);
  const marcaPart = codeFromMarca(marca);
  return marcaPart ? `${nombrePart}-${marcaPart}` : nombrePart;
}
