import { ActividadesModel } from './actividades.model';

describe('Chofer independiente en actividades', () => {
  const setup = () => {
    const db = { callFunctionJson: jest.fn().mockResolvedValue({ registro: { id: 1 } }) };
    return { db, model: new ActividadesModel(db as never) };
  };

  it('conserva la orden y el responsable al enviar el chofer seleccionado', async () => {
    const { db, model } = setup();
    await model.crear('Reparto', null, '2026-09-22', '15:00', '18:00', 1, 2, 3, 4, 5, null, 6, null, 11, null, 27);
    expect(db.callFunctionJson).toHaveBeenCalledWith('age_crear_actividad', [
      'Reparto', null, '2026-09-22', '15:00', '18:00', 1, 2, 3, 4, 5, null, 6, null, 11, null, 27,
    ]);
  });

  it('permite heredar el chofer de la orden cuando no se envía uno', async () => {
    const { db, model } = setup();
    await model.crear('Reparto', null, '2026-09-22', null, null, 1, 2, null, null, 5, null, 6, null, 11);
    expect(db.callFunctionJson.mock.calls[0][1].at(-1)).toBeNull();
  });

  it('envía el cambio de chofer sin reemplazar los ítems en edición', async () => {
    const { db, model } = setup();
    await model.actualizar(9, null, null, null, null, null, null, null, null, 4, null, null, 6, null, null, null, 28);
    const [name, args] = db.callFunctionJson.mock.calls[0];
    expect(name).toBe('age_actualizar_actividad');
    expect(args[10]).toBe(4);
    expect(args.slice(-2)).toEqual([null, 28]);
  });
});
