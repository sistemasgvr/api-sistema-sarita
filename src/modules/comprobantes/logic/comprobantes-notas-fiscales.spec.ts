import { ComprobantesLogic } from './comprobantes.logic';

describe('Documentos fiscales de corrección', () => {
  const model = { notaFiscalCorreccion: jest.fn(), notasFiscalesCorreccion: jest.fn(), obtenerCompleto: jest.fn() };
  const provider = { generarPdfNota: jest.fn() };
  const logic = new ComprobantesLogic(model as never, {} as never, provider as never, {} as never, {} as never, {} as never, {} as never, {} as never);
  beforeEach(() => jest.resetAllMocks());

  it('no permite descargar una nota que pertenece a otra venta', async () => {
    model.notaFiscalCorreccion.mockResolvedValue({ rows: [] });
    await expect(logic.pdfNotaFiscalCorreccion(69, 2)).rejects.toThrow('Nota fiscal no encontrada');
    expect(model.notaFiscalCorreccion).toHaveBeenCalledWith(69, 2);
    expect(provider.generarPdfNota).not.toHaveBeenCalled();
  });

  it.each(['PREPARADO', 'EN_CURSO', 'POR_CONFIRMAR', 'RECHAZADO', 'DESCARTADO_NO_EMITIDO'])('no entrega como emitida una nota %s', async estado => {
    model.notaFiscalCorreccion.mockResolvedValue({ rows: [{ estado, payload: {} }] });
    await expect(logic.pdfNotaFiscalCorreccion(69, 1)).rejects.toThrow('aceptación confirmada');
    expect(provider.generarPdfNota).not.toHaveBeenCalled();
  });

  it('genera el PDF desde la referencia fiscal almacenada, aunque cambie la cabecera de la venta', async () => {
    const payload = { tipoDoc: '07', serie: 'FC02', correlativo: '1', numDocfectado: 'F002-1' };
    model.notaFiscalCorreccion.mockResolvedValue({ rows: [{ estado: 'ACEPTADO', payload }] });
    provider.generarPdfNota.mockResolvedValue(Buffer.from('%PDF'));
    await expect(logic.pdfNotaFiscalCorreccion(69, 1)).resolves.toEqual(Buffer.from('%PDF'));
    expect(provider.generarPdfNota).toHaveBeenCalledWith(payload);
  });
});
