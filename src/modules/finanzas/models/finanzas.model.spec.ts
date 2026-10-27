import { FinanzasModel } from './finanzas.model';
import { FinanzasLogic } from '../logic/finanzas.logic';

describe('Editar garantía', () => {
  it('llama a ven_actualizar_garantia con medio, cuenta y nº de operación', async () => {
    const db = {
      callFunctionJson: jest.fn().mockResolvedValue({ registro: { id: 7 }, avisos: [] }),
    };
    await new FinanzasModel(db as never).actualizarGarantia(7, {
      fecha: '2026-10-20',
      idMedioPago: 1,
      idCuentaBancaria: 4,
      numeroOperacion: 'OP-1',
      importe: 50,
      idUsuarioAuditoria: 2,
    } as never);
    expect(db.callFunctionJson).toHaveBeenCalledWith('ven_actualizar_garantia', [
      7,
      '2026-10-20',
      null,
      1,
      4,
      'OP-1',
      50,
      null,
      2,
    ]);
  });

  it('devuelve la garantía con los avisos de la función', async () => {
    const model = {
      actualizarGarantia: jest.fn().mockResolvedValue({
        registro: { id: 7, monto_cobrado: 50 },
        avisos: ['La caja del 20/10/2026 está cerrada: sus totales no cambian hasta reabrirla y cerrarla'],
      }),
    };
    const logic = new FinanzasLogic(model as never, {} as never);
    const result = await logic.actualizarGarantia(7, {} as never);
    expect(result).toEqual({
      id: 7,
      monto_cobrado: 50,
      avisos: ['La caja del 20/10/2026 está cerrada: sus totales no cambian hasta reabrirla y cerrarla'],
    });
  });

  it('propaga el error de la función como BadRequest', async () => {
    const model = {
      actualizarGarantia: jest.fn().mockResolvedValue({ error: 'El monto no puede ser menor', registro: null }),
    };
    const logic = new FinanzasLogic(model as never, {} as never);
    await expect(logic.actualizarGarantia(7, {} as never)).rejects.toThrow('El monto no puede ser menor');
  });
});
