import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Logger } from '@nestjs/common';
import bwipjs from 'bwip-js';
import PDFDocument from 'pdfkit';

/**
 * Base común de las etiquetas adhesivas para la impresora térmica (cilindros,
 * productos, ubicaciones): la página del PDF mide exactamente el papel, 50 mm de
 * ancho × 25 mm de alto, así el driver imprime 1:1 sin escalar ni centrar. Un
 * lote va como un PDF de varias páginas, una etiqueta por página.
 */
export const MM = 72 / 25.4;
export const ETIQUETA_ANCHO_PT = 50 * MM;
export const ETIQUETA_ALTO_PT = 25 * MM;
export const ETIQUETA_MARGEN_PT = 1.5 * MM;
export const ETIQUETA_ANCHO_UTIL_PT =
  ETIQUETA_ANCHO_PT - ETIQUETA_MARGEN_PT * 2;

const LOGO_PNG = 'logo-sarita-etiqueta.png';
const logger = new Logger('EtiquetaPdf');
let logoCache: Buffer | null | undefined;

/**
 * El logo vive en src/assets y nest-cli lo copia a dist al compilar, por eso se
 * busca en ambas rutas; sin logo la etiqueta igual se imprime.
 */
export function cargarLogoEtiqueta(): Buffer | null {
  if (logoCache !== undefined) return logoCache;
  const rutas = [
    join(__dirname, '..', '..', 'assets', LOGO_PNG),
    join(process.cwd(), 'src', 'assets', LOGO_PNG),
    join(process.cwd(), 'dist', 'assets', LOGO_PNG),
  ];
  const ruta = rutas.find((candidata) => existsSync(candidata));
  if (!ruta)
    logger.warn(`No se encontró ${LOGO_PNG}; las etiquetas saldrán sin logo`);
  logoCache = ruta ? readFileSync(ruta) : null;
  return logoCache;
}

/** Code 128 como PNG a alta resolución; pdfkit lo escala al ancho pedido. */
export function codigoBarrasPng(texto: string): Promise<Buffer> {
  return bwipjs.toBuffer({
    bcid: 'code128',
    text: texto,
    scale: 4,
    height: 10,
    includetext: false,
    paddingwidth: 0,
  });
}

export interface EtiquetaDoc {
  doc: PDFKit.PDFDocument;
  /** Resuelve con el PDF completo cuando se llama a `doc.end()`. */
  terminado: Promise<Buffer>;
}

export function crearEtiquetaDoc(titulo: string): EtiquetaDoc {
  const doc = new PDFDocument({
    size: [ETIQUETA_ANCHO_PT, ETIQUETA_ALTO_PT],
    margin: 0,
    info: { Title: titulo, Author: 'Sistema Sarita' },
  });
  const chunks: Buffer[] = [];
  doc.on('data', (chunk: Buffer) => chunks.push(chunk));
  const terminado = new Promise<Buffer>((resolve, reject) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });
  return { doc, terminado };
}

/**
 * Fila superior estándar: logo a la izquierda y código de barras a la derecha
 * con su valor en texto debajo (por si la lectora falla). Devuelve la `y`
 * donde empieza el bloque de datos.
 */
export function dibujarCabeceraEtiqueta(
  doc: PDFKit.PDFDocument,
  barras: Buffer,
  textoBarras: string,
): number {
  const x0 = ETIQUETA_MARGEN_PT;
  const y0 = ETIQUETA_MARGEN_PT;
  const filaAlto = 9 * MM;
  const logoAncho = 16 * MM;
  const logo = cargarLogoEtiqueta();
  if (logo)
    doc.image(logo, x0, y0, { fit: [logoAncho, filaAlto], valign: 'center' });

  const barrasX = x0 + logoAncho + 1.5 * MM;
  const barrasAncho = x0 + ETIQUETA_ANCHO_UTIL_PT - barrasX;
  const barrasAlto = 6.2 * MM;
  doc.image(barras, barrasX, y0, { width: barrasAncho, height: barrasAlto });
  doc
    .font('Helvetica')
    .fontSize(6)
    .text(textoBarras, barrasX, y0 + barrasAlto + 0.5 * MM, {
      width: barrasAncho,
      align: 'center',
      characterSpacing: 0.4,
      lineBreak: false,
    });

  return y0 + filaAlto + 1.6 * MM;
}

/** Alto de una fila de datos «Etiqueta: valor». */
export const ETIQUETA_FILA_DATOS_PT = 3.7 * MM;

/** «Etiqueta:» en normal y el valor en negrita, en una sola línea con elipsis. */
export function escribirDato(
  doc: PDFKit.PDFDocument,
  etiqueta: string,
  valor: string,
  x: number,
  y: number,
  ancho: number,
  etiquetaAncho: number,
): void {
  doc.font('Helvetica').fontSize(6).text(etiqueta, x, y, { lineBreak: false });
  doc
    .font('Helvetica-Bold')
    .fontSize(6.5)
    .text(valor, x + etiquetaAncho, y, {
      width: ancho - etiquetaAncho,
      lineBreak: false,
      ellipsis: true,
    });
}

/** `2031-03-01` (o ISO completo) → `01/03/2031`; sin fecha → `—`. */
export function formatearFechaEtiqueta(valor?: string | null): string {
  const iso = (valor ?? '').slice(0, 10);
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : '—';
}
