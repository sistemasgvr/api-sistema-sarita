/**
 * Búsqueda de los documentos de origen de una percepción/retención.
 *
 * El usuario escribe el código como lo recuerda («F001-123», «f001 123»,
 * «123») mientras la BD guarda el correlativo con ceros («00000123»), así que
 * comparar contra `serie || '-' || numero` tal cual no encontraba nada. Aquí
 * ambos lados se reducen a la misma forma canónica —minúsculas, sin acentos y
 * solo letras y dígitos— y el correlativo se compara con y sin relleno.
 */

/** Acentos y eñes que TRANSLATE debe plegar; el orden debe casar con REEMPLAZO. */
const ACENTOS = 'áàäâéèëêíìïîóòöôúùüûñç';
const REEMPLAZO = 'aaaaeeeeiiiioooouuuunc';

/** Diacríticos que deja sueltos la descomposición NFD. */
const DIACRITICOS = new RegExp('[\u0300-\u036f]', 'g');

/** Misma forma canónica que `sqlCanonico`, aplicada al término que escribe el usuario. */
export function normalizarBusqueda(termino: string | null | undefined): string {
  return (termino ?? '')
    .normalize('NFD')
    .replace(DIACRITICOS, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

/** Expresión SQL que reduce una columna de texto a la forma canónica. */
function sqlCanonico(expresion: string): string {
  return `REGEXP_REPLACE(TRANSLATE(LOWER(${expresion}), '${ACENTOS}', '${REEMPLAZO}'), '[^a-z0-9]', '', 'g')`;
}

/**
 * Condición `LIKE` contra serie-número (con y sin ceros a la izquierda), nombre
 * de la contraparte y su número de documento. `origen` es el alias del
 * comprobante/compra y `contraparte` el de cli_clientes.
 */
export function sqlCoincideBusqueda(
  origen: string,
  contraparte: string,
  parametro = '$2',
): string {
  const patron = `'%' || ${parametro} || '%'`;
  const serieNumero = `COALESCE(${origen}.serie, '') || COALESCE(${origen}.numero, '')`;
  const serieNumeroSinCeros = `COALESCE(${origen}.serie, '') || LTRIM(COALESCE(${origen}.numero, ''), '0')`;
  const nombre = `COALESCE(NULLIF(TRIM(${contraparte}.razon_social), ''), CONCAT_WS(' ', ${contraparte}.nombres, ${contraparte}.apellido_paterno, ${contraparte}.apellido_materno), '')`;
  return [
    `${sqlCanonico(serieNumero)} LIKE ${patron}`,
    `${sqlCanonico(serieNumeroSinCeros)} LIKE ${patron}`,
    `${sqlCanonico(nombre)} LIKE ${patron}`,
    `${sqlCanonico(`COALESCE(${contraparte}.numero_documento, '')`)} LIKE ${patron}`,
  ].join('\n              OR ');
}

/** Serie disponible con su correlativo, como la devuelven las funciones `*_listar_series_*`. */
export interface SerieTributo {
  serie: string;
  ultimo_numero: string | null;
  siguiente_numero: string;
  total: number;
}
