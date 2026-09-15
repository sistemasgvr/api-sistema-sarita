import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../../database/database.service';
import { FacturacionCredentialsService } from './facturacion-credentials.service';

describe('Credenciales GRE por empresa', () => {
  const rows: Record<number, Record<string, unknown>> = {
    1: { ruc_empresa: '20111111111', api_token: 'token-a', client_id: 'oauth-a', pse_habilitado: true },
    2: { ruc_empresa: '20222222222', api_token: 'token-b', client_id: 'oauth-b', pse_habilitado: true },
  };
  let query: jest.Mock;
  let service: FacturacionCredentialsService;
  beforeEach(() => {
    query = jest.fn(async (_sql: string, [id]: number[]) => {
      await new Promise(resolve => setImmediate(resolve));
      return { rows: rows[id] ? [rows[id]] : [] };
    });
    service = new FacturacionCredentialsService(
      { query } as unknown as DatabaseService,
      { get: () => 'secreto-global-que-no-debe-usarse' } as unknown as ConfigService,
    );
  });

  it('aísla credenciales durante emisiones concurrentes y llamadas anidadas', async () => {
    const results = await Promise.all([1, 2].map(id => service.withEmpresa(id, async () => {
      const first = await service.resolve();
      await new Promise(resolve => setImmediate(resolve));
      const second = await service.resolve();
      return [first.token, second.token, second.defaultRuc];
    })));
    expect(results).toEqual([
      ['token-a', 'token-a', '20111111111'],
      ['token-b', 'token-b', '20222222222'],
    ]);
  });

  it('no completa secretos ausentes con los de otra empresa', async () => {
    const creds = await service.withEmpresa(1, () => service.resolve());
    expect(creds.password).toBe('');
    expect(creds.clientSecret).toBe('');
  });

  it('rechaza una empresa sin configuración en lugar de usar la primera', async () => {
    await expect(service.withEmpresa(3, () => service.resolve())).rejects.toThrow('única configuración');
  });

  it('rechaza un RUC SUNAT distinto del emisor del documento', async () => {
    query.mockResolvedValue({ rows: [{ ...rows[1], ruc_emisor: '20222222222' }] });
    await expect(service.withEmpresa(1, () => service.resolve())).rejects.toThrow('no coincide');
  });

  it('propaga fallos de base de datos sin recurrir a credenciales globales', async () => {
    query.mockRejectedValue(new Error('database unavailable'));
    await expect(service.withEmpresa(1, () => service.resolve())).rejects.toThrow('database unavailable');
  });
});
