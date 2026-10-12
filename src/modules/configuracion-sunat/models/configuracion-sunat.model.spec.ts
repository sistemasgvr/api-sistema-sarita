import { ConfiguracionSunatModel, ConfiguracionSunatWriteParams } from './configuracion-sunat.model';
import { DatabaseService } from '../../../database/database.service';

describe('Configuración SUNAT: credenciales de validez independientes', () => {
  const params: ConfiguracionSunatWriteParams = {
    idEmpresa: 1, usuarioSol: null, claveSol: null,
    certificadoDigital: null, claveCertificado: null, idAmbiente: null,
    proveedorPse: null, pseHabilitado: null, apiBaseUrl: null,
    apiToken: null, apiUsuario: null, apiClave: null, rucEmisor: null,
    clientId: null, clientSecret: null, timeoutMs: null,
    validezClientId: 'id-consulta', validezClientSecret: 'clave-consulta',
  };

  function setup() {
    const db = {
      withTransaction: jest.fn(async (operation: () => Promise<unknown>) => operation()),
      callFunctionJson: jest.fn().mockResolvedValue({ registro: { id: 1 } }),
      query: jest.fn().mockResolvedValue({ rows: [] }),
    };
    return { db, model: new ConfiguracionSunatModel(db as unknown as DatabaseService) };
  }

  it.each(['crear', 'actualizar'] as const)('guarda validez al %s sin pasar sus claves a GRE', async (action) => {
    const { db, model } = setup();
    if (action === 'crear') await model.crear(params);
    else await model.actualizar(1, params);
    expect(db.withTransaction).toHaveBeenCalledTimes(1);
    const [, legacyArgs] = db.callFunctionJson.mock.calls[0];
    expect(legacyArgs).not.toContain('id-consulta');
    expect(legacyArgs).not.toContain('clave-consulta');
    expect(db.query.mock.calls[0][1]).toEqual([1, 'id-consulta', 'clave-consulta']);
    expect(db.query.mock.calls[0][0]).not.toMatch(/\bSET\s+client_id\b|\bclient_secret\s*=/);
    expect(db.callFunctionJson).toHaveBeenLastCalledWith('gen_obtener_configuracion_sunat', [1]);
  });

  it('conserva la configuración al recibir una edición sin campos de validez', async () => {
    const { db, model } = setup();
    await model.actualizar(1, { ...params, validezClientId: null, validezClientSecret: null });
    expect(db.query).not.toHaveBeenCalled();
  });

  it('no guarda claves si la función de configuración falla o no encuentra el registro', async () => {
    const { db, model } = setup();
    db.callFunctionJson.mockResolvedValue({ registro: null, error: 'No encontrada' });
    await model.actualizar(999, params);
    expect(db.query).not.toHaveBeenCalled();
  });

  it('propaga el fallo de escritura para que la transacción completa revierta', async () => {
    const { db, model } = setup();
    db.query.mockRejectedValue(new Error('fallo de almacenamiento'));
    await expect(model.actualizar(1, params)).rejects.toThrow('fallo de almacenamiento');
    expect(db.callFunctionJson).toHaveBeenCalledTimes(1);
  });
});
