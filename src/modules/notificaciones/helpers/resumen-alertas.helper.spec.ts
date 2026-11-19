import {
  resumenCxcVencidas,
  resumenCxpPorVencer,
  resumenGarantiasPorDevolver,
  resumenPh,
} from './resumen-alertas.helper';

describe('resúmenes de alertas diarias', () => {
  it('no genera alerta sin registros', () => {
    expect(resumenPh([], 60)).toBeNull();
    expect(resumenCxcVencidas([])).toBeNull();
    expect(resumenCxpPorVencer([], 7)).toBeNull();
    expect(resumenGarantiasPorDevolver([])).toBeNull();
  });

  it('P.H.: un solo mensaje para muchos cilindros, con el más próximo', () => {
    const r = resumenPh(
      [
        {
          id: 1,
          codigo_balon: 'B-100',
          fecha_proxima: '2026-12-30',
          dias_restantes: 41,
        },
        {
          id: 2,
          codigo_balon: 'B-200',
          fecha_proxima: '2026-11-25',
          dias_restantes: 6,
        },
        {
          id: 3,
          codigo_balon: 'B-300',
          fecha_proxima: '2027-01-10',
          dias_restantes: 52,
        },
      ],
      60,
    );
    expect(r?.mensaje).toContain('3 cilindros tienen');
    expect(r?.mensaje).toContain('B-200, en 6 día(s)');
  });

  it('CxC: total, clientes y la más antigua', () => {
    const r = resumenCxcVencidas([
      { id: 1, tercero: 'Clínica Sur', dias: 45, saldo: 1200 },
      { id: 2, tercero: 'Clínica Sur', dias: 3, saldo: '300.50' },
      { id: 3, tercero: 'Taller Norte', dias: 10, saldo: 99.5 },
    ]);
    expect(r?.mensaje).toContain('3 cuentas por cobrar vencidas de 2 clientes');
    expect(r?.mensaje).toMatch(/1[,.]?600\.00/);
    expect(r?.mensaje).toContain('Clínica Sur, 45 día(s)');
  });

  it('CxP: separa vencidas de próximas', () => {
    const r = resumenCxpPorVencer(
      [
        { id: 1, dias: 2, saldo: 100 },
        { id: 2, dias: -3, saldo: 50 },
        { id: 3, dias: 0, saldo: 25 },
      ],
      7,
    );
    expect(r?.titulo).toBe('Cuentas por pagar vencidas');
    expect(r?.mensaje).toContain('1 cuenta por pagar vencida');
    expect(r?.mensaje).toContain('2 vencen en los próximos 7 días');
  });

  it('garantías: un mensaje con el total', () => {
    const r = resumenGarantiasPorDevolver([
      { id: 1, nombre_cliente: 'Ana', dias: 5, saldo: 150 },
    ]);
    expect(r?.mensaje).toContain('1 garantía sigue con saldo');
    expect(r?.mensaje).toContain('Ana, devuelto hace 5 día(s)');
  });
});
