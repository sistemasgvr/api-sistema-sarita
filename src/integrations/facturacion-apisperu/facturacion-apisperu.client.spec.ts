import { HttpService } from '@nestjs/axios';
import { FacturacionCredentialsService } from '../facturacion-electronica/facturacion-credentials.service';
import { FacturacionApisperuClient } from './facturacion-apisperu.client';

describe('Selección del emisor en el PSE', () => {
  it('no sincroniza credenciales en la primera empresa si el RUC solicitado no existe', async () => {
    const client = new FacturacionApisperuClient(
      {} as HttpService,
      { resolve: async () => ({ clientId: 'client-b', clientSecret: 'secret-b' }) } as unknown as FacturacionCredentialsService,
    );
    jest.spyOn(client, 'listarEmpresas').mockResolvedValue([{ id: 1, ruc: '20111111111' }]);
    const update = jest.spyOn(client, 'actualizarEmpresa');
    await expect(client.asegurarCredencialesGreEnEmpresa('20222222222')).rejects.toThrow('No se encontró');
    expect(update).not.toHaveBeenCalled();
  });
});


describe('Credenciales según el entorno GRE', () => {
  function setup(environment: unknown, clientId = 'real-client') {
    const client = new FacturacionApisperuClient({} as HttpService, {
      resolve: async () => ({ clientId, clientSecret: 'real-secret' }),
    } as unknown as FacturacionCredentialsService);
    jest.spyOn(client, 'listarEmpresas').mockResolvedValue([{ id: 18, ruc: '20111111111' }]);
    jest.spyOn(client, 'obtenerEmpresa').mockResolvedValue({ environment });
    const update = jest.spyOn(client, 'actualizarEmpresa').mockResolvedValue({});
    return { client, update };
  }
  it('sincroniza OAuth y SOL públicos de prueba en beta', async () => {
    const { client, update } = setup({ nombre: 'beta', api_cpe_url: 'https://gre-test.nubefact.com/v1' });
    await client.asegurarCredencialesGreEnEmpresa('20111111111');
    expect(update).toHaveBeenCalledWith(18, expect.objectContaining({
      client_id: 'test-85e5b0ae-255c-4891-a595-0b98c65c9854', sol_user: 'MODDATOS', sol_pass: 'MODDATOS',
    }));
  });
  it('mantiene credenciales reales y no modifica SOL en producción', async () => {
    const { client, update } = setup({ nombre: 'produccion' });
    await client.asegurarCredencialesGreEnEmpresa('20111111111');
    expect(update).toHaveBeenCalledWith(18, { client_id: 'real-client', client_secret: 'real-secret' });
  });
  it('bloquea beta con URL de producción', async () => {
    const { client, update } = setup({ nombre: 'beta', api_cpe_url: 'https://api-cpe.sunat.gob.pe/v1' });
    await expect(client.asegurarCredencialesGreEnEmpresa('20111111111')).rejects.toThrow('URLs');
    expect(update).not.toHaveBeenCalled();
  });
  it('bloquea credenciales de prueba fuera de beta', async () => {
    const { client, update } = setup('produccion', 'test-client');
    await expect(client.asegurarCredencialesGreEnEmpresa('20111111111')).rejects.toThrow('solo');
    expect(update).not.toHaveBeenCalled();
  });
});
