import { PDFDocument, StandardFonts } from 'pdf-lib';
import { agregarAnexoGlosa } from './comprobante-pdf-anexo.util';

async function pdfDeUnaPagina(): Promise<Buffer> {
  const documento = await PDFDocument.create();
  const pagina = documento.addPage([595.28, 841.89]);
  const fuente = await documento.embedFont(StandardFonts.Helvetica);
  pagina.drawText('FACTURA ELECTRONICA F001-00000001', {
    x: 48,
    y: 780,
    size: 12,
    font: fuente,
  });
  return Buffer.from(await documento.save());
}

async function paginas(pdf: Buffer): Promise<number> {
  return (await PDFDocument.load(pdf)).getPageCount();
}

describe('agregarAnexoGlosa', () => {
  it('agrega una página con la glosa al PDF del proveedor', async () => {
    const original = await pdfDeUnaPagina();

    const resultado = await agregarAnexoGlosa(original, {
      glosa: 'Entrega en el almacén de la planta, horario de 8 a 17 h.',
      tipoDocumento: 'FACTURA ELECTRÓNICA',
      serieNumero: 'F001-00000001',
      fecha: '2026-11-05',
      cliente: 'ACME GAS SAC',
    });

    expect(await paginas(resultado)).toBe(2);
    const salida = await PDFDocument.load(resultado);
    expect(salida.getPage(1).getSize()).toEqual(salida.getPage(0).getSize());
  });

  it('no toca el PDF cuando no hay glosa', async () => {
    const original = await pdfDeUnaPagina();

    await expect(agregarAnexoGlosa(original, { glosa: '   ' })).resolves.toBe(
      original,
    );
    await expect(agregarAnexoGlosa(original, { glosa: null })).resolves.toBe(
      original,
    );
  });

  it('divide una glosa larga en varias líneas sin romper el PDF', async () => {
    const original = await pdfDeUnaPagina();
    const glosa =
      'Se entrega el cilindro con válvula y regulador en perfecto estado. '.repeat(
        6,
      );

    const resultado = await agregarAnexoGlosa(original, { glosa });

    expect(await paginas(resultado)).toBe(2);
    expect(resultado.length).toBeGreaterThan(original.length);
  });

  it('devuelve el PDF original si no se puede interpretar', async () => {
    const invalido = Buffer.from('no es un pdf');

    await expect(
      agregarAnexoGlosa(invalido, { glosa: 'Glosa de prueba' }),
    ).resolves.toBe(invalido);
  });

  it('no falla con comillas tipográficas ni emojis', async () => {
    const original = await pdfDeUnaPagina();

    const resultado = await agregarAnexoGlosa(original, {
      glosa: 'Cliente “preferente” — entrega 🚚 en 24 h.',
    });

    expect(await paginas(resultado)).toBe(2);
  });
});
