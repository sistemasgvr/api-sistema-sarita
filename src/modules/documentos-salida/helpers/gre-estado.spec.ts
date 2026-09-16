import { resolverEstadoGre } from './gre-estado';

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
