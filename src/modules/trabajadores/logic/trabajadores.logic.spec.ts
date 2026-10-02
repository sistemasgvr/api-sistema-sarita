import { TrabajadoresLogic } from './trabajadores.logic';

function setup() {
  const registro = { id: 7, nombres: 'Ana', apellido_paterno: 'Prueba', es_usuario: false, id_usuario: null as number | null };
  const model = {
    crear: jest.fn(async () => ({ registro })),
    actualizar: jest.fn(async () => ({ registro })),
    obtenerPorId: jest.fn(async () => ({ registro })),
  };
  const usuarios = { crear: jest.fn(async () => { registro.es_usuario = true; registro.id_usuario = 9; }) };
  const db = { withTransaction: jest.fn(async (operation: () => Promise<unknown>) => operation()) };
  const logic = new TrabajadoresLogic(model as never, usuarios as never, {} as never, db as never);
  const dto = { nombres: 'Ana', correo: 'ana@example.test', numeroDocumento: '12345678', crearUsuario: true, idRol: 2 };
  return { logic, model, usuarios, db, dto, registro };
}

describe('Acceso desde trabajador', () => {
  it('crea usuario con el rol y permisos del operador y devuelve el vínculo actualizado', async () => {
    const { logic, usuarios, db, dto } = setup();
    const result = await logic.crear(dto, ['auth.todo']);
    expect(usuarios.crear).toHaveBeenCalledWith(expect.objectContaining({ idTrabajador: 7, idRol: 2 }), ['auth.todo']);
    expect(result.es_usuario).toBe(true);
    expect(db.withTransaction).toHaveBeenCalledTimes(1);
  });

  it('crea el acceso al editar un trabajador existente sin volver a registrarlo', async () => {
    const { logic, usuarios, model, dto } = setup();
    await logic.actualizar(7, dto, ['usuarios.crear']);
    expect(model.crear).not.toHaveBeenCalled();
    expect(usuarios.crear).toHaveBeenCalledWith(expect.objectContaining({ nombre: 'aprueba', idTrabajador: 7, idRol: 2 }), ['usuarios.crear']);
  });

  it('rechaza permisos insuficientes antes de guardar al trabajador', async () => {
    const { logic, model, dto } = setup();
    await expect(logic.crear(dto, [])).rejects.toThrow('permiso');
    expect(model.crear).not.toHaveBeenCalled();
  });

  it('exige rol antes de guardar y no informa éxito si falla la cuenta', async () => {
    const { logic, model, usuarios, dto } = setup();
    await expect(logic.crear({ ...dto, idRol: undefined }, ['auth.todo'])).rejects.toThrow('rol');
    expect(model.crear).not.toHaveBeenCalled();
    usuarios.crear.mockRejectedValueOnce(new Error('Correo duplicado'));
    await expect(logic.crear(dto, ['auth.todo'])).rejects.toThrow('Correo duplicado');
  });

  it('no duplica una cuenta ya vinculada', async () => {
    const { logic, registro, usuarios, dto } = setup();
    registro.es_usuario = true;
    registro.id_usuario = 9;
    await expect(logic.actualizar(7, dto, ['auth.todo'])).rejects.toThrow('ya tiene');
    expect(usuarios.crear).not.toHaveBeenCalled();
  });
});
