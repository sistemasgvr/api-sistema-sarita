import { PDFDocument, StandardFonts } from 'pdf-lib';
import { ComprobantesLogic } from './comprobantes.logic';

async function pdfDeUnaPagina(): Promise<Buffer> {
  const documento = await PDFDocument.create();
  const pagina = documento.addPage([595.28, 841.89]);
  const fuente = await documento.embedFont(StandardFonts.Helvetica);
  pagina.drawText('REPRESENTACION IMPRESA', {
    x: 48,
    y: 780,
    size: 12,
    font: fuente,
  });
  return Buffer.from(await documento.save());
}

function crearLogic(glosa: string | null, pdf: Buffer) {
  const logic = Object.create(ComprobantesLogic.prototype) as ComprobantesLogic;
  const facturacionClient = {
    getConfigStatus: jest
      .fn()
      .mockResolvedValue({ enabled: true, configured: true }),
    generarPdfFacturaBoleta: jest.fn().mockResolvedValue(pdf),
  };

  Object.assign(logic, {
    model: {
      obtenerCompleto: jest.fn().mockResolvedValue({
        registro: {
          id: 1,
          codigo_tipo_comprobante: '03',
          serie: 'B001',
          numero: '1',
          id_cliente: 5,
          glosa,
          fecha: '2026-11-05',
        },
        detalles: [{ id: 1 }],
      }),
      obtenerEmpresaEmisora: jest
        .fn()
        .mockResolvedValue({ id: 1, ruc: '20111111111' }),
    },
    clientesModel: {
      obtenerPorId: jest
        .fn()
        .mockResolvedValue({ registro: { id_distrito: null } }),
    },
    facturacionClient,
    invoiceMapper: {
      mapComprobanteToInvoicePayload: jest.fn().mockReturnValue({}),
    },
  });

  return { logic, facturacionClient };
}

describe('PDF A4 del comprobante con glosa', () => {
  it('agrega la glosa como anexo al PDF del proveedor', async () => {
    const { logic, facturacionClient } = crearLogic(
      'Entrega en tienda',
      await pdfDeUnaPagina(),
    );

    const { buffer, filename } = await logic.generarPdf(1, 'a4');

    expect(facturacionClient.generarPdfFacturaBoleta).toHaveBeenCalledWith(
      expect.anything(),
    );
    expect((await PDFDocument.load(buffer)).getPageCount()).toBe(2);
    expect(filename).toBe('B001-1-a4.pdf');
  });

  it('no agrega páginas cuando el comprobante no tiene glosa', async () => {
    const { logic } = crearLogic(null, await pdfDeUnaPagina());

    const { buffer } = await logic.generarPdf(1, 'a4');

    expect((await PDFDocument.load(buffer)).getPageCount()).toBe(1);
  });
});
