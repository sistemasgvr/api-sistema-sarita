import { ArgumentsHost, BadRequestException, Logger } from '@nestjs/common';
import { HttpExceptionFilter } from './http-exception.filter';

function pgError(
  code: string,
  message: string,
  extra: Record<string, unknown> = {},
) {
  return Object.assign(new Error(message), { code, ...extra });
}

function ejecutar(exception: unknown) {
  const json = jest.fn<void, [{ message: string; statusCode: number }]>();
  const status = jest.fn<{ json: typeof json }, [number]>(() => ({ json }));
  const response = { status, locals: {} as Record<string, unknown> };
  const host = {
    switchToHttp: () => ({
      getRequest: () => ({ method: 'POST', originalUrl: '/api/prueba' }),
      getResponse: () => response,
    }),
  } as unknown as ArgumentsHost;

  new HttpExceptionFilter().catch(exception, host);

  return {
    statusCode: status.mock.calls[0][0],
    body: json.mock.calls[0][0],
  };
}

describe('HttpExceptionFilter', () => {
  beforeAll(() => {
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
  });

  afterAll(() => {
    jest.restoreAllMocks();
  });

  it('devuelve 400 con el mensaje de la función para RAISE EXCEPTION (P0001)', () => {
    const { statusCode, body } = ejecutar(
      pgError('P0001', 'No se puede anular: el stock ya fue consumido'),
    );
    expect(statusCode).toBe(400);
    expect(body.message).toBe('No se puede anular: el stock ya fue consumido');
  });

  it('devuelve 400 con el mensaje de la función para ERRCODE 22023 (pagos de una venta)', () => {
    const { statusCode, body } = ejecutar(
      pgError('22023', 'La suma de los pagos excede el total del comprobante'),
    );
    expect(statusCode).toBe(400);
    expect(body.statusCode).toBe(400);
    expect(body.message).toBe(
      'La suma de los pagos excede el total del comprobante',
    );
  });

  it('mantiene el 500 genérico si el mensaje de negocio viene vacío', () => {
    const { statusCode, body } = ejecutar(pgError('22023', '   '));
    expect(statusCode).toBe(500);
    expect(body.message).toBe('Error interno del servidor');
  });

  it('traduce el duplicado de condición de pago (caso del 18/11) a 409 con mensaje específico', () => {
    const { statusCode, body } = ejecutar(
      pgError(
        '23505',
        'duplicate key value violates unique constraint "gen_condicion_pago_codigo_key"',
        { constraint: 'gen_condicion_pago_codigo_key' },
      ),
    );
    expect(statusCode).toBe(409);
    expect(body.message).toContain('Ya existe una condición de pago');
    expect(body.message).not.toContain('duplicate key');
  });

  it('no expone el texto técnico de un error de sistema', () => {
    const { statusCode, body } = ejecutar(
      pgError('42883', 'function public.xyz(integer) does not exist'),
    );
    expect(statusCode).toBe(500);
    expect(body.message).toBe('Error interno del servidor');
  });

  it('no confunde errores de red de Node con errores de la base', () => {
    const { statusCode } = ejecutar(
      pgError('ECONNREFUSED', 'connect ECONNREFUSED'),
    );
    expect(statusCode).toBe(500);
  });

  it('sigue respetando las HttpException de Nest', () => {
    const { statusCode, body } = ejecutar(
      new BadRequestException('Dato inválido'),
    );
    expect(statusCode).toBe(400);
    expect(body.message).toBe('Dato inválido');
  });
});
