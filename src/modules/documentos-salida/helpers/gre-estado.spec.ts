import { motivoEnvioNoRecibido, resolverEstadoGre } from './gre-estado';

describe('estado GRE basado en evidencia de SUNAT', () => {
  it.each([
    [{ success: true }, 'PENDIENTE'],
    [{ success: true, code: '98' }, 'PENDIENTE'],
    [{ success: true, ticket: 'test-ticket' }, 'PENDIENTE'],
    [{ success: false, error: { message: 'timeout' } }, 'PENDIENTE'],
    [{ code: null }, 'PENDIENTE'],
    [{ code: '' }, 'PENDIENTE'],
    [{ code: 0 }, 'PENDIENTE'],
    [{}, 'PENDIENTE'],
    [null, 'PENDIENTE'],
    [{ sunatResponse: { cdrResponse: { code: '0' } } }, 'ACEPTADO'],
    [{ cdrResponse: { accepted: true } }, 'ACEPTADO'],
    [{ cdrResponse: { accepted: true, code: '2567' } }, 'RECHAZADO'],
    [{ cdrResponse: { accepted: false, code: '0' } }, 'RECHAZADO'],
    [{ success: false, error: { code: '2108' } }, 'RECHAZADO'],
    [{ code: '99' }, 'RECHAZADO'],
    // Respuestas contradictorias, incompletas o desconocidas: nunca aceptado.
    [{ success: true, cdrResponse: {} }, 'PENDIENTE'],
    [{ success: true, cdrResponse: { code: '0', accepted: false } }, 'RECHAZADO'],
    [{ success: true, code: '98', cdrResponse: { code: '0' } }, 'PENDIENTE'],
    [{ sunatResponse: { success: true, error: { code: '1033', message: 'ya fue presentado' } } }, 'PENDIENTE'],
    [{ sunatResponse: { estado: 'DESCONOCIDO' } }, 'PENDIENTE'],
    ['texto', 'PENDIENTE'],
  ])('clasifica %j como %s', (response, expected) => {
    expect(resolverEstadoGre(response)).toBe(expected);
  });
});

describe('envío que SUNAT no recibió', () => {
  // Respuesta real de producción (2026-10-06): credenciales OAuth/SOL rechazadas.
  const sin401 = {
    sunatResponse: {
      success: false,
      error: {
        code: 'API',
        message:
          '[401] Client error: `POST https://api-cpe.sunat.gob.pe/v1/contribuyente/gem/comprobantes/10175332796-31-V001-1` ' +
          'resulted in a `401 Unauthorized` response:\n{"status":401,"message":"Unauthorized"}\n\n',
      },
    },
  };

  it('un 4xx sin ticket no fue recibido y explica qué revisar', () => {
    const motivo = motivoEnvioNoRecibido(sin401);
    expect(motivo).toContain('HTTP 401 Unauthorized');
    expect(motivo).toContain('usuario SOL');
  });

  it.each([
    [{ sunatResponse: { success: false, error: { message: 'timeout' } } }],
    [{ sunatResponse: { success: false, error: { message: '[500] Server error' } } }],
    [{ sunatResponse: { success: true, ticket: 'abc', error: { message: '[401] x' } } }],
    [{ sunatResponse: { success: true } }],
    [null],
  ])('no lo da por no recibido si es ambiguo o hay ticket: %j', (response) => {
    expect(motivoEnvioNoRecibido(response)).toBeNull();
  });
});
