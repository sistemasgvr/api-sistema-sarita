/**
 * SUNAT valida `cbc:Note` (descripción de leyenda) como alfanumérico de 1 a
 * 200 caracteres, sin tabs ni saltos de línea (rechazo 3006).
 */
export const GLOSA_SUNAT_MAX = 200;

/**
 * Deja la glosa en el formato que acepta SUNAT: un solo espacio entre palabras
 * y como máximo 200 caracteres. Devuelve null si no queda texto.
 */
export function glosaParaSunat(valor?: string | null): string | null {
  if (typeof valor !== 'string') {
    return null;
  }

  const normalizada = valor.replace(/\s+/g, ' ').trim();
  if (!normalizada) {
    return null;
  }

  // Corta por puntos de código para no partir emojis ni caracteres compuestos.
  const recortada = Array.from(normalizada)
    .slice(0, GLOSA_SUNAT_MAX)
    .join('')
    .trim();

  return recortada || null;
}
