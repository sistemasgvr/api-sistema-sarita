import { Logger } from '@nestjs/common';
import { PDFDocument, PDFFont, PDFPage, StandardFonts, rgb } from 'pdf-lib';

const logger = new Logger('ComprobantePdfGlosa');

const MARGEN = 48;
const ALTO_LINEA = 14;

export interface AnexoGlosaDatos {
  glosa?: string | null;
  tipoDocumento?: string | null;
  serieNumero?: string | null;
  fecha?: string | null;
  cliente?: string | null;
}

export async function agregarAnexoGlosa(
  pdf: Buffer,
  datos: AnexoGlosaDatos,
): Promise<Buffer> {
  const glosa = normalizarTexto(datos.glosa ?? '').trim();
  if (!glosa) {
    return pdf;
  }

  try {
    const documento = await PDFDocument.load(pdf);
    const { width, height } = documento.getPage(0).getSize();
    const fuente = await documento.embedFont(StandardFonts.Helvetica);
    const negrita = await documento.embedFont(StandardFonts.HelveticaBold);
    const anchoUtil = width - MARGEN * 2;
    const limiteInferior = MARGEN + 48;

    let pagina = nuevaPagina(documento, width, height, negrita, false);
    let y = height - MARGEN - 46;

    const escribir = (
      texto: string,
      opciones: {
        size: number;
        negrita?: boolean;
        color?: ReturnType<typeof rgb>;
      },
    ) => {
      pagina.drawText(texto, {
        x: MARGEN,
        y,
        size: opciones.size,
        font: opciones.negrita ? negrita : fuente,
        color: opciones.color ?? rgb(0.1, 0.1, 0.1),
      });
      y -= opciones.size + 5;
    };

    const cabecera = [
      datos.tipoDocumento && datos.serieNumero
        ? `Comprobante: ${datos.tipoDocumento} ${datos.serieNumero}`
        : datos.serieNumero
          ? `Comprobante: ${datos.serieNumero}`
          : null,
      datos.fecha ? `Fecha: ${formatearFecha(datos.fecha)}` : null,
      datos.cliente
        ? `Cliente: ${normalizarTexto(datos.cliente).trim()}`
        : null,
    ].filter((linea): linea is string => Boolean(linea));

    for (const linea of cabecera) {
      escribir(linea, { size: 9 });
    }

    y -= 8;
    escribir('Glosa', { size: 10, negrita: true });
    y -= 2;

    for (const linea of dividirEnLineas(glosa, fuente, 10, anchoUtil)) {
      if (y < limiteInferior) {
        pagina = nuevaPagina(documento, width, height, negrita, true);
        y = height - MARGEN - 46;
      }
      pagina.drawText(linea, {
        x: MARGEN,
        y,
        size: 10,
        font: fuente,
        color: rgb(0.1, 0.1, 0.1),
      });
      y -= ALTO_LINEA;
    }

    pagina.drawText(
      'Anexo generado por el sistema. La representación impresa oficial del comprobante corresponde a las páginas anteriores.',
      {
        x: MARGEN,
        y: MARGEN - 6,
        size: 7,
        font: fuente,
        color: rgb(0.45, 0.45, 0.45),
        maxWidth: anchoUtil,
        lineHeight: 9,
      },
    );

    return Buffer.from(await documento.save());
  } catch (error: unknown) {
    const mensaje = error instanceof Error ? error.message : String(error);
    logger.warn(
      `No se pudo agregar la glosa al PDF del comprobante: ${mensaje}`,
    );
    return pdf;
  }
}

function nuevaPagina(
  documento: PDFDocument,
  width: number,
  height: number,
  negrita: PDFFont,
  continuacion: boolean,
): PDFPage {
  const pagina = documento.addPage([width, height]);
  pagina.drawText(
    continuacion
      ? 'INFORMACIÓN ADICIONAL (continuación)'
      : 'INFORMACIÓN ADICIONAL',
    {
      x: MARGEN,
      y: height - MARGEN - 14,
      size: 13,
      font: negrita,
      color: rgb(0.07, 0.07, 0.07),
    },
  );
  pagina.drawLine({
    start: { x: MARGEN, y: height - MARGEN - 24 },
    end: { x: width - MARGEN, y: height - MARGEN - 24 },
    thickness: 0.8,
    color: rgb(0.55, 0.55, 0.55),
  });
  return pagina;
}

function dividirEnLineas(
  texto: string,
  fuente: PDFFont,
  size: number,
  ancho: number,
): string[] {
  const lineas: string[] = [];

  for (const parrafo of texto.split('\n')) {
    const palabras = parrafo.split(/\s+/).filter(Boolean);

    if (palabras.length === 0) {
      lineas.push('');
      continue;
    }

    let actual = '';
    for (const palabra of palabras) {
      const candidata = actual ? `${actual} ${palabra}` : palabra;

      if (fuente.widthOfTextAtSize(candidata, size) <= ancho) {
        actual = candidata;
        continue;
      }

      if (actual) {
        lineas.push(actual);
      }

      if (fuente.widthOfTextAtSize(palabra, size) <= ancho) {
        actual = palabra;
        continue;
      }

      let trozo = '';
      for (const caracter of palabra) {
        if (fuente.widthOfTextAtSize(trozo + caracter, size) <= ancho) {
          trozo += caracter;
        } else {
          lineas.push(trozo);
          trozo = caracter;
        }
      }
      actual = trozo;
    }

    if (actual) {
      lineas.push(actual);
    }
  }

  return lineas;
}

function formatearFecha(fecha: string): string {
  const iso = fecha.slice(0, 10);
  const partes = iso.split('-');
  return partes.length === 3 && partes[0].length === 4
    ? `${partes[2]}/${partes[1]}/${partes[0]}`
    : fecha;
}

function normalizarTexto(texto: string): string {
  return texto
    .replace(/\r\n?/g, '\n')
    .replace(/\t/g, ' ')
    .replace(/[\u2018\u2019\u201A\u201B]/g, "'")
    .replace(/[\u201C\u201D\u201E]/g, '"')
    .replace(/[\u2013\u2014\u2212]/g, '-')
    .replace(/\u2026/g, '...')
    .replace(/\u00A0/g, ' ')
    .replace(/[^\n\x20-\x7E\u00A1-\u00FF]/g, '');
}
