import { ComprobanteInvoiceMapper } from './comprobante-invoice.mapper';

const empresa = {
  ruc: '20123456789',
  razon_social: 'EMPRESA SAC',
  direccion: 'AV. PRINCIPAL 123',
  codigo_ubigeo: '140101',
  nombre_departamento: 'LAMBAYEQUE',
  nombre_provincia: 'CHICLAYO',
  nombre_distrito: 'CHICLAYO',
};

const cliente = {
  nombre_tipo_documento: 'RUC',
  numero_documento: '20600000001',
  razon_social: 'CLIENTE SAC',
};

function comprobante(registro: Record<string, unknown>, cuotas: unknown[] = []) {
  return {
    registro: {
      serie: 'FC01',
      numero: '00000006',
      fecha: '2026-11-17',
      codigo_moneda: 'PEN',
      valor_venta: 508.47,
      igv: 91.53,
      sub_total: 600,
      total_importe: 600,
      serie_comprobante_origen: 'F002',
      numero_comprobante_origen: '00000197',
      codigo_tipo_comprobante_origen: '01',
      ...registro,
    },
    detalles: [
      {
        item: 1,
        id_producto: 1,
        descripcion: 'OXIGENO MEDICINAL',
        cantidad: 1,
        valor_venta: 508.47,
        impuesto: 91.53,
        importe: 600,
        codigo_afectacion_igv: '10',
        porcentaje_igv: 18,
      },
    ],
    cuotas,
  } as never;
}

describe('ComprobanteInvoiceMapper · notas de crédito', () => {
  const mapper = new ComprobanteInvoiceMapper();

  it('no envía forma de pago en una NC de anulación (evita rechazo 3246)', () => {
    const payload = mapper.mapComprobanteToInvoicePayload(
      comprobante({ codigo_tipo_comprobante: '07', codigo_motivo_nota: '01' }),
      empresa,
      cliente,
    );

    expect(payload.formaPago).toBeUndefined();
    expect(payload.cuotas).toBeUndefined();
    expect(payload.codMotivo).toBe('01');
    expect(payload.numDocfectado).toBe('F002-197');
  });

  it('tampoco la envía aunque la NC herede crédito de la factura', () => {
    const payload = mapper.mapComprobanteToInvoicePayload(
      comprobante({ codigo_tipo_comprobante: '07', codigo_motivo_nota: '01', dias_credito: 30 }),
      empresa,
      cliente,
    );

    expect(payload.formaPago).toBeUndefined();
    expect(payload.cuotas).toBeUndefined();
  });

  it('sí envía crédito y cuotas en la NC motivo 13', () => {
    const payload = mapper.mapComprobanteToInvoicePayload(
      comprobante(
        { codigo_tipo_comprobante: '07', codigo_motivo_nota: '13' },
        [{ numero_cuota: 1, monto: 600, fecha_vencimiento: '2026-12-17' }],
      ),
      empresa,
      cliente,
    );

    expect(payload.formaPago).toEqual({ moneda: 'PEN', tipo: 'Credito', monto: 600 });
    expect(payload.cuotas).toHaveLength(1);
  });

  it('la factura sigue enviando su forma de pago', () => {
    const payload = mapper.mapComprobanteToInvoicePayload(
      comprobante({ codigo_tipo_comprobante: '01', serie: 'F002' }),
      empresa,
      cliente,
    );

    expect(payload.formaPago).toEqual({ moneda: 'PEN', tipo: 'Contado' });
  });
});
