import { HttpService } from '@nestjs/axios';
import { FacturacionCredentialsService } from '../facturacion-electronica/facturacion-credentials.service';
import { FacturacionApisperuClient } from './facturacion-apisperu.client';

const TEST_CLIENT_ID = 'test-85e5b0ae-255c-4891-a595-0b98c65c9854';

function setup(
  empresa: Record<string, unknown> | null,
  creds: Record<string, unknown> = {},
) {
  const client = new FacturacionApisperuClient({} as HttpService, {
    resolve: () => Promise.resolve({
      enabled: true, token: 'tok', username: '', password: '', defaultRuc: '',
      clientId: 'real-client', clientSecret: 'real-secret', solUser: 'USUARIO', solPass: 'CLAVE',
      ...creds,
    }),
  } as unknown as FacturacionCredentialsService);
  jest.spyOn(client, 'listarEmpresas').mockResolvedValue([{ id: 18, ruc: '20111111111' }]);
  jest.spyOn(client, 'obtenerEmpresa').mockResolvedValue(empresa ?? {});
  const update = jest.spyOn(client, 'actualizarEmpresa').mockResolvedValue({});
  const send = jest.spyOn(client as unknown as { request: () => Promise<unknown> }, 'request').mockResolvedValue({ hash: 'h' });
  return { client, update, send };
}

const BETA = { nombre: 'beta', api_cpe_url: 'https://gre-test.nubefact.com/v1', auth_url: 'https://gre-test.nubefact.com/v1' };

describe('Verificar conexión y empresa (solo lecturas)', () => {
  it('detecta RUC ausente en el PSE sin tocar otra empresa', async () => {
    const { client, update } = setup({ environment: BETA });
    const r = await client.verificarEmpresaGre('20222222222');
    expect(r.rucCoincide).toBe(false);
    expect(r.listo).toBe(false);
    expect(r.problemas.join()).toContain('20222222222');
    expect(update).not.toHaveBeenCalled();
  });

  it('en beta queda listo con las credenciales de prueba ya registradas en el PSE, sin exigir OAuth real local', async () => {
    const { client, update } = setup({ environment: BETA, client_id: TEST_CLIENT_ID }, { clientId: '', clientSecret: '' });
    const r = await client.verificarEmpresaGre('20111111111');
    expect(r).toEqual(expect.objectContaining({ entorno: 'beta', listo: true, esCredencialPrueba: true, companyId: 18 }));
    expect(update).not.toHaveBeenCalled();
  });

  it('en beta con client_id real pide sincronizar', async () => {
    const { client } = setup({ environment: BETA, client_id: 'real-client' });
    const r = await client.verificarEmpresaGre('20111111111');
    expect(r.listo).toBe(false);
    expect(r.problemas.join()).toContain('Sincronizar');
  });

  it('en beta con URL de producción no está listo', async () => {
    const { client } = setup({ environment: { nombre: 'beta', api_cpe_url: 'https://api-cpe.sunat.gob.pe/v1' }, client_id: TEST_CLIENT_ID });
    const r = await client.verificarEmpresaGre('20111111111');
    expect(r.urlsCoherentes).toBe(false);
    expect(r.listo).toBe(false);
  });

  it('en producción exige OAuth real, SOL real y coincidencia con el PSE', async () => {
    const conPrueba = setup({ environment: 'produccion', client_id: TEST_CLIENT_ID, sol_user: 'MODDATOS' });
    const r1 = await conPrueba.client.verificarEmpresaGre('20111111111');
    expect(r1.entorno).toBe('produccion');
    expect(r1.listo).toBe(false);
    expect(r1.problemas.join()).toMatch(/prueba/);

    const sinSol = setup({ environment: 'produccion', client_id: 'real-client', sol_user: 'USUARIO' }, { solUser: '', solPass: '' });
    const r2 = await sinSol.client.verificarEmpresaGre('20111111111');
    expect(r2.listo).toBe(false);
    expect(r2.problemas.join()).toContain('SOL');

    const ok = setup({ environment: 'produccion', client_id: 'real-client', sol_user: 'USUARIO' });
    const r3 = await ok.client.verificarEmpresaGre('20111111111');
    expect(r3.listo).toBe(true);
  });

  it('detecta RUC emisor local distinto al de la empresa', async () => {
    const { client } = setup({ environment: BETA, client_id: TEST_CLIENT_ID }, { defaultRuc: '20999999999' });
    const r = await client.verificarEmpresaGre('20111111111');
    expect(r.listo).toBe(false);
    expect(r.problemas.join()).toContain('20999999999');
  });
});

describe('Sincronizar configuración GRE (única escritura al PSE)', () => {
  it('en beta registra OAuth y SOL públicos de prueba sin usar los secretos locales', async () => {
    const { client, update } = setup({ environment: BETA, client_id: 'real-client' });
    jest.spyOn(client, 'obtenerEmpresa')
      .mockResolvedValueOnce({ environment: BETA, client_id: 'real-client' })
      .mockResolvedValueOnce({ environment: BETA, client_id: TEST_CLIENT_ID });
    const r = await client.sincronizarCredencialesGre('20111111111');
    expect(update).toHaveBeenCalledWith(18, {
      client_id: TEST_CLIENT_ID, client_secret: 'test-Hty/M6QshYvPgItX2P0+Kw==', sol_user: 'MODDATOS', sol_pass: 'MODDATOS',
    });
    expect(r.sincronizado).toBe(true);
    expect(r.listo).toBe(true);
  });

  it('en producción envía OAuth y SOL reales de la configuración local', async () => {
    const { client, update } = setup({ environment: 'produccion', client_id: TEST_CLIENT_ID, sol_user: 'MODDATOS' });
    await client.sincronizarCredencialesGre('20111111111');
    expect(update).toHaveBeenCalledWith(18, {
      client_id: 'real-client', client_secret: 'real-secret', sol_user: 'USUARIO', sol_pass: 'CLAVE',
    });
  });

  it('en producción rechaza credenciales de prueba o SOL ausente', async () => {
    const prueba = setup({ environment: 'produccion' }, { clientId: 'test-x', clientSecret: 's' });
    await expect(prueba.client.sincronizarCredencialesGre('20111111111')).rejects.toThrow('BETA');
    expect(prueba.update).not.toHaveBeenCalled();

    const sinSol = setup({ environment: 'produccion' }, { solUser: '', solPass: '' });
    await expect(sinSol.client.sincronizarCredencialesGre('20111111111')).rejects.toThrow('SOL');
    expect(sinSol.update).not.toHaveBeenCalled();
  });

  it('no escribe si el RUC no existe en el PSE', async () => {
    const { client, update } = setup({ environment: BETA });
    const r = await client.sincronizarCredencialesGre('20222222222');
    expect(r.sincronizado).toBe(false);
    expect(update).not.toHaveBeenCalled();
  });
});

describe('Envío de GRE', () => {
  it('no modifica la empresa del PSE al enviar', async () => {
    const { client, update, send } = setup({ environment: BETA, client_id: TEST_CLIENT_ID });
    await client.enviarGuiaRemision({ company: { ruc: '20111111111' } });
    expect(update).not.toHaveBeenCalled();
    expect(send).toHaveBeenCalledWith('POST', '/despatch/send', expect.anything());
  });

  it('se niega a enviar si la verificación no está lista', async () => {
    const { client, send } = setup({ environment: BETA, client_id: 'real-client' });
    await expect(client.enviarGuiaRemision({ company: { ruc: '20111111111' } })).rejects.toThrow('no está lista');
    expect(send).not.toHaveBeenCalled();
  });
});
