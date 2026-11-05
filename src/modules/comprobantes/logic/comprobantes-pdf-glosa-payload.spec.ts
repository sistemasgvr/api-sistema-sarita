import { ComprobantesLogic } from './comprobantes.logic';

describe('PDF A4 del comprobante con glosa', () => {
  function crearLogic(glosa: string | null) {
    const logic = Object.create(
      ComprobantesLogic.prototype,
    ) as ComprobantesLogic;
    const facturacionClient = {
      getConfigStatus: jest
        .fn()
        .mockResolvedValue({ enabled: true, configured: true }),
      generarPdfFacturaBoleta: jest.fn().mockResolvedValue(Buffer.from('%PDF')),
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

  it('pasa la glosa del comprobante al PDF A4 del proveedor', async () => {
    const { logic, facturacionClient } = crearLogic('Entrega en tienda');

    const { filename } = await logic.generarPdf(1, 'a4');

    expect(facturacionClient.generarPdfFacturaBoleta).toHaveBeenCalledWith(
      expect.anything(),
      { glosa: 'Entrega en tienda' },
    );
    expect(filename).toBe('B001-1-a4.pdf');
  });

  it('pasa glosa nula cuando el comprobante no tiene glosa', async () => {
    const { logic, facturacionClient } = crearLogic(null);

    await logic.generarPdf(1, 'a4');

    expect(facturacionClient.generarPdfFacturaBoleta).toHaveBeenCalledWith(
      expect.anything(),
      { glosa: null },
    );
  });
});
