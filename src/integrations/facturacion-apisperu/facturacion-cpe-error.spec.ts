import { of, throwError } from 'rxjs';
import { HttpService } from '@nestjs/axios';
import { FacturacionApisperuClient } from './facturacion-apisperu.client';
import { FacturacionCredentialsService } from '../facturacion-electronica/facturacion-credentials.service';

describe('Errores internos de APIs Perú sin filtración de tokens', () => {
  function setup(response: unknown, failed = false) {
    const http = { request: jest.fn().mockReturnValue(failed ? throwError(() => response) : of(response)) };
    const credentials = { resolve: jest.fn().mockResolvedValue({ enabled: true, token: 'token-api', baseUrl: 'https://facturacion.apisperu.com/api/v1', timeoutMs: 60000 }) };
    return { http, client: new FacturacionApisperuClient(http as unknown as HttpService, credentials as unknown as FacturacionCredentialsService) };
  }
  it.each([false, true])('explica el timeout sin reintentar, HTTP de error: %s', async (failed) => {
    const message = 'cURL error 28: Operation timed out after 45000 milliseconds /invoice/send?token=secreto-interno';
    const response = failed ? { message: 'HTTP 500', response: { status: 500, data: { error: message } } } : { status: 200, data: { success: false, error: { message } } };
    const { client, http } = setup(response, failed);
    try { await client.enviarFacturaBoleta({}); throw new Error('Se esperaba un error'); }
    catch (error) {
      expect((error as Error).message).toContain('por confirmar');
      expect((error as Error).message).not.toContain('secreto-interno');
    }
    expect(http.request).toHaveBeenCalledTimes(1);
  });
});
