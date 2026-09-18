import { armarTributoDesdeOrigen, type OrigenTributo } from './tributo-desde-origen.helper';

function venta(overrides: Partial<OrigenTributo> = {}): OrigenTributo {
  return {
    id: 10, estado: 1, serie: 'F001', numero: '00000012', fecha: '2026-09-10', tipo_doc: '01',
    total: '1180.00', moneda: 'PEN', id_contraparte: 15, nombre_contraparte: 'CLIENTE SAC',
    documento_contraparte: '20100000141', nombre_estado_sunat: 'ACEPTADO', con_tributo: false, id_sucursal: 1,
    ...overrides,
  };
}

function compra(overrides: Partial<OrigenTributo> = {}): OrigenTributo {
  return venta({ id: 20, serie: 'E001', numero: '55', nombre_estado_sunat: undefined, ...overrides });
}

describe('Percepción desde comprobantes de venta', () => {
  it('toma cliente, sucursal e importes del comprobante y aplica la tasa del régimen', () => {
    const r = armarTributoDesdeOrigen('percepcion', { regimen: '01', tasa: 2, fechaEmision: '2026-09-17', origenes: [{ id: 10 }] }, [venta()]);
    expect(r).toEqual(expect.objectContaining({ idContraparte: 15, idSucursal: 1, tasa: 2, baseImponible: 1180, montoTributo: 23.6, montoNeto: 1203.6 }));
    expect(r.detalles[0]).toEqual({
      id_origen: 10, tipo_doc: '01', num_doc: 'F001-00000012', fecha_emision: '2026-09-10', fecha_operacion: '2026-09-17',
      moneda: 'PEN', imp_total: 1180, imp_tributo: 23.6, imp_neto: 1203.6,
    });
  });

  it('suma varios comprobantes del mismo cliente y redondea a centavos', () => {
    const r = armarTributoDesdeOrigen(
      'percepcion',
      { regimen: '03', tasa: 0.5, fechaEmision: '2026-09-17', origenes: [{ id: 10 }, { id: 11, fechaOperacion: '2026-09-15' }] },
      [venta(), venta({ id: 11, numero: '00000013', total: '33.33', fecha: '2026-09-12' })],
    );
    expect(r.tasa).toBe(0.5);
    expect(r.detalles.map((d) => d.imp_tributo)).toEqual([5.9, 0.17]);
    expect(r.montoTributo).toBe(6.07);
    expect(r.baseImponible).toBe(1213.33);
    expect(r.detalles[1].fecha_operacion).toBe('2026-09-15');
  });

  it('admite comprobantes aceptados o pendientes de envío y rechaza los rechazados, dados de baja o no aplicables', () => {
    const solicitud = { regimen: '01', tasa: 2, fechaEmision: '2026-09-17', origenes: [{ id: 10 }] };
    expect(armarTributoDesdeOrigen('percepcion', solicitud, [venta({ nombre_estado_sunat: 'PENDIENTE' })]).montoTributo).toBe(23.6);
    expect(armarTributoDesdeOrigen('percepcion', solicitud, [venta({ nombre_estado_sunat: null })]).montoTributo).toBe(23.6);
    for (const estado of ['RECHAZADO', 'BAJA', 'NO_APLICA']) {
      expect(() => armarTributoDesdeOrigen('percepcion', solicitud, [venta({ nombre_estado_sunat: estado })]))
        .toThrow(`está ${estado} ante SUNAT`);
    }
  });

  it.each([
    [{ estado: 0 }, 'anulado'],
    [{ con_tributo: true }, 'ya tiene percepción'],
    [{ moneda: 'USD' }, 'no está en soles'],
    [{ tipo_doc: '07' }, 'no es factura ni boleta'],
    [{ documento_contraparte: '' }, 'no tiene número de documento'],
    [{ documento_contraparte: '00000000' }, 'no tiene número de documento'],
    [{ total: '0' }, 'no tiene importe'],
  ] as [Partial<OrigenTributo>, string][])('rechaza %j', (overrides, mensaje) => {
    expect(() => armarTributoDesdeOrigen('percepcion', { regimen: '01', tasa: 2, fechaEmision: '2026-09-17', origenes: [{ id: 10 }] }, [venta(overrides)]))
      .toThrow(mensaje);
  });

  it('rechaza comprobantes de distintos clientes, repetidos o inexistentes', () => {
    const base = { regimen: '01', tasa: 2, fechaEmision: '2026-09-17' };
    expect(() => armarTributoDesdeOrigen('percepcion', { ...base, origenes: [{ id: 10 }, { id: 11 }] }, [venta(), venta({ id: 11, id_contraparte: 99 })]))
      .toThrow('mismo cliente');
    expect(() => armarTributoDesdeOrigen('percepcion', { ...base, origenes: [{ id: 10 }, { id: 10 }] }, [venta()])).toThrow('repetidos');
    expect(() => armarTributoDesdeOrigen('percepcion', { ...base, origenes: [{ id: 10 }, { id: 12 }] }, [venta()])).toThrow('No se encontró el comprobante 12');
  });

  it('valida las fechas de cobro contra emisión del comprobante y de la percepción', () => {
    expect(() => armarTributoDesdeOrigen('percepcion', { regimen: '01', tasa: 2, fechaEmision: '2026-09-17', origenes: [{ id: 10, fechaOperacion: '2026-09-01' }] }, [venta()]))
      .toThrow('anterior a su emisión');
    expect(() => armarTributoDesdeOrigen('percepcion', { regimen: '01', tasa: 2, fechaEmision: '2026-09-17', origenes: [{ id: 10, fechaOperacion: '2026-09-20' }] }, [venta()]))
      .toThrow('posterior a la emisión');
  });

  it('aplica la tasa recibida y exige que sea un porcentaje usable', () => {
    const r = armarTributoDesdeOrigen('percepcion', { regimen: '01', tasa: 1, fechaEmision: '2026-09-17', origenes: [{ id: 10 }] }, [venta()]);
    expect(r.montoTributo).toBe(11.8);
    expect(() => armarTributoDesdeOrigen('percepcion', { regimen: '09', tasa: 0, fechaEmision: '2026-09-17', origenes: [{ id: 10 }] }, [venta()])).toThrow('tasa');
    expect(() => armarTributoDesdeOrigen('percepcion', { regimen: '01', tasa: 120, fechaEmision: '2026-09-17', origenes: [{ id: 10 }] }, [venta()])).toThrow('tasa');
  });
});

describe('Retención desde compras', () => {
  it('descuenta la retención del importe a pagar y no exige estado SUNAT', () => {
    const r = armarTributoDesdeOrigen('retencion', { regimen: '01', tasa: 3, fechaEmision: '2026-09-17', origenes: [{ id: 20 }] }, [compra()]);
    expect(r).toEqual(expect.objectContaining({ tasa: 3, baseImponible: 1180, montoTributo: 35.4, montoNeto: 1144.6 }));
    expect(r.detalles[0].num_doc).toBe('E001-55');
  });

  it('exige proveedor con RUC y factura con serie y número', () => {
    expect(() => armarTributoDesdeOrigen('retencion', { regimen: '01', tasa: 3, fechaEmision: '2026-09-17', origenes: [{ id: 20 }] }, [compra({ documento_contraparte: '12345678' })]))
      .toThrow('proveedor con RUC');
    expect(() => armarTributoDesdeOrigen('retencion', { regimen: '01', tasa: 3, fechaEmision: '2026-09-17', origenes: [{ id: 20 }] }, [compra({ numero: null })]))
      .toThrow('no tiene serie y número');
    expect(() => armarTributoDesdeOrigen('retencion', { regimen: '01', tasa: 3, fechaEmision: '2026-09-17', origenes: [{ id: 20 }] }, [compra({ con_tributo: true })]))
      .toThrow('ya tiene retención');
  });
});
