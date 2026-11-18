import { ConflictException } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { CondicionesPagoModel } from './condiciones-pago.model';

describe('CondicionesPagoModel', () => {
  const callFunctionJson = jest.fn();
  const model = new CondicionesPagoModel({
    callFunctionJson,
  } as unknown as DatabaseService);

  beforeEach(() => callFunctionJson.mockReset());

  it('permite crear crédito de 21 días con un código nuevo', async () => {
    const result = { registro: { codigo: 'CRED21', dias_credito: 21 } };
    callFunctionJson.mockResolvedValue(result);

    await expect(
      model.crear('CRED21', 'Crédito 21 días', 21, null, null, 1),
    ).resolves.toEqual(result);
    expect(callFunctionJson).toHaveBeenCalledWith('gen_crear_condicion_pago', [
      'CRED21',
      'Crédito 21 días',
      21,
      null,
      null,
      1,
    ]);
  });

  it.each(['crear', 'actualizar'])(
    'informa el código duplicado al %s',
    async (operation) => {
      callFunctionJson.mockRejectedValue(
        Object.assign(new Error('duplicate key'), {
          code: '23505',
          constraint: 'gen_condicion_pago_codigo_key',
        }),
      );

      const result =
        operation === 'crear'
          ? model.crear('CREDITO', 'Crédito 21 días', 21, null, null)
          : model.actualizar(1, 'CREDITO', null, 21, null, null);

      await expect(result).rejects.toThrow(
        new ConflictException(
          'Ya existe una condición de pago con ese código. Usa un código diferente, por ejemplo CRED21 para crédito de 21 días.',
        ),
      );
    },
  );

  it.each([
    { code: '23505', constraint: 'gen_condicion_pago_pkey' },
    { code: '23503', constraint: 'gen_condicion_pago_codigo_key' },
    {},
  ])(
    'conserva otros errores sin confundirlos con códigos repetidos: %o',
    async (details) => {
      const error = Object.assign(new Error('otro error'), details);
      callFunctionJson.mockRejectedValue(error);

      await expect(
        model.crear('CRED21', 'Crédito 21 días', 21, null, null),
      ).rejects.toBe(error);
    },
  );
});
