import { UsuariosModel } from './usuarios.model';

describe('Trabajador vinculado del usuario', () => {
  const vinculo = { id: 3, id_trabajador: 8, nombre_trabajador: 'Billy Reaño' };
  it('completa el listado aunque la función SQL no incluya el vínculo', async () => {
    const db = {
      callFunctionJson: jest.fn().mockResolvedValue({ registros: [{ id: 3, nombre: 'breano' }], total: 1 }),
      query: jest.fn().mockResolvedValue({ rows: [vinculo] }),
    };
    const result = await new UsuariosModel(db as never).listar({ offset: 0 } as never);
    expect(result.registros[0]).toEqual({ nombre: 'breano', ...vinculo });
    expect(db.query).toHaveBeenCalledWith(expect.any(String), [[3]]);
  });
  it('incluye nombre y vínculo en el detalle, sin sustituir el alias', async () => {
    const db = {
      callFunctionJson: jest.fn().mockResolvedValue({ registro: { id: 3, nombre: 'breano' } }),
      query: jest.fn().mockResolvedValue({ rows: [vinculo] }),
    };
    const result = await new UsuariosModel(db as never).obtenerPorId(3);
    expect(result.registro).toEqual({ nombre: 'breano', ...vinculo });
  });
});
