import { HttpStatus } from '@nestjs/common';
import { esPgError, traducirPgError } from './pg-error.helper';

describe('traducirPgError', () => {
  it('usa el mensaje genérico de 23505 si la constraint no está mapeada', () => {
    const r = traducirPgError({
      code: '23505',
      message: 'duplicate key',
      constraint: 'ven_resumen_diario_fecha_correlativo_key',
    });
    expect(r?.status).toBe(HttpStatus.CONFLICT);
    expect(r?.message).toContain('Ya existe un registro');
  });

  it.each([
    'gen_sucursal_codigo_key',
    'gen_configuracion_servicio_codigo_key',
    'gen_licencia_codigo_key',
    'gen_empresa_ruc_key',
  ])('tiene mensaje específico para %s', (constraint) => {
    const r = traducirPgError({ code: '23505', message: 'x', constraint });
    expect(r?.message).toMatch(/^Ya existe/);
  });

  it('distingue 23503 al eliminar algo en uso', () => {
    const r = traducirPgError({
      code: '23503',
      message: 'update or delete violates foreign key',
      detail: 'Key (id)=(5) is still referenced from table "ven_comprobante".',
    });
    expect(r?.status).toBe(HttpStatus.CONFLICT);
    expect(r?.message).toContain('dependen de este');
  });

  it('distingue 23503 al guardar con una referencia inexistente', () => {
    const r = traducirPgError({
      code: '23503',
      message: 'insert violates foreign key',
      detail: 'Key (id_cliente)=(99) is not present in table "cli_clientes".',
    });
    expect(r?.status).toBe(HttpStatus.BAD_REQUEST);
    expect(r?.message).toContain('ya no existe');
  });

  it('devuelve el mensaje del trigger en un 23514 sin constraint', () => {
    const r = traducirPgError({
      code: '23514',
      message: 'La numeración de este comprobante quedó bloqueada.',
    });
    expect(r).toEqual({
      status: HttpStatus.BAD_REQUEST,
      message: 'La numeración de este comprobante quedó bloqueada.',
    });
  });

  it('oculta el texto técnico de un CHECK real (23514 con constraint)', () => {
    const r = traducirPgError({
      code: '23514',
      message: 'new row violates check constraint "chk_x"',
      constraint: 'chk_x',
    });
    expect(r?.message).toBe(
      'Uno de los valores está fuera del rango permitido.',
    );
  });

  it.each(['23502', '22P02', '22001', '22003', '40001', '40P01'])(
    'traduce %s',
    (code) => {
      const r = traducirPgError({ code, message: 'texto técnico' });
      expect(r).not.toBeNull();
      expect(r?.message).not.toBe('texto técnico');
    },
  );

  it('deja como 500 los errores de sistema', () => {
    expect(
      traducirPgError({ code: '42P01', message: 'relation does not exist' }),
    ).toBeNull();
    expect(
      traducirPgError({ code: '08006', message: 'connection failure' }),
    ).toBeNull();
  });
});

describe('esPgError', () => {
  it('reconoce un SQLSTATE y descarta códigos de Node', () => {
    expect(esPgError(Object.assign(new Error('x'), { code: '23505' }))).toBe(
      true,
    );
    expect(
      esPgError(Object.assign(new Error('x'), { code: 'ECONNRESET' })),
    ).toBe(false);
    expect(esPgError({ code: '23505' })).toBe(false);
  });
});
