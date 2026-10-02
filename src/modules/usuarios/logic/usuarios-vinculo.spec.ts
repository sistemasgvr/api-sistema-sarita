import { UsuariosLogic } from './usuarios.logic';

describe('Conservación del trabajador vinculado', () => {
  function setup(idTrabajador: number | null) {
    const model = {
      obtenerPorId: jest.fn().mockResolvedValue({ registro: { id: 3, id_trabajador: idTrabajador } }),
      actualizar: jest.fn().mockResolvedValue({ registro: { id: 3 } }),
    };
    return { model, logic: new UsuariosLogic(model as never, {} as never) };
  }
  it('rechaza cambiar el vínculo existente desde la API', async () => {
    const { model, logic } = setup(8);
    await expect(logic.actualizar(3, { idTrabajador: 9 })).rejects.toThrow('no se puede cambiar');
    expect(model.actualizar).not.toHaveBeenCalled();
  });
  it('permite editar el alias manteniendo el vínculo', async () => {
    const { model, logic } = setup(8);
    await logic.actualizar(3, { nombre: 'breano', idTrabajador: 8 });
    expect(model.actualizar).toHaveBeenCalledWith(3, 'breano', null, null, 8, undefined);
  });
});
