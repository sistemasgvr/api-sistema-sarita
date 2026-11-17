import { ComprobanteInvoiceMapper } from './comprobante-invoice.mapper';
import type { ComprobanteCompletoResult } from '../interfaces/comprobante.interface';

describe('Condiciones de pago de notas de crédito', () => {
  const mapper = new ComprobanteInvoiceMapper();
  const empresa = {
    ruc: '20123456789', razon_social: 'Empresa',
    direccion: 'Calle de prueba 123', codigo_ubigeo: '140106',
  };
  const cliente = { nombre_tipo_documento: 'RUC', numero_documento: '20600000001', razon_social: 'Cliente' };
  const documento: ComprobanteCompletoResult = {
    registro: {
      id: 1, id_tipo_comprobante: 7, codigo_tipo_comprobante: '07',
      serie: 'FC01', numero: '00000006', fecha: '2026-11-17', id_cliente: 1,
      codigo_moneda: 'PEN', codigo_motivo_nota: '01',
      codigo_tipo_comprobante_origen: '01', serie_comprobante_origen: 'F002',
      numero_comprobante_origen: '00000197',
    },
    detalles: [{
      id: 1, item: 1, id_producto: 1, descripcion: 'Producto',
      cantidad: 1, precio_unitario: 118, valor_venta: 100,
      impuesto: 18, importe: 118, codigo_afectacion_igv: '10',
    }],
  };

  it.each([0, 30])('omite formaPago y cuotas para anulación aunque el origen tenga %i días de crédito', dias => {
    const payload = mapper.mapComprobanteToInvoicePayload({
      ...documento,
      registro: { ...documento.registro!, dias_credito: dias },
      cuotas: [{ id: 1, numero_cuota: 1, monto: 118, fecha_vencimiento: '2026-12-17' }],
    }, empresa, cliente);
    expect(payload).not.toHaveProperty('formaPago');
    expect(payload).not.toHaveProperty('cuotas');
    expect(payload).toMatchObject({
      tipoDoc: '07', codMotivo: '01', numDocfectado: 'F002-197',
      mtoImpVenta: 118, mtoIGV: 18,
    });
  });

  it('conserva las condiciones y cuotas de las facturas al crédito', () => {
    const payload = mapper.mapComprobanteToInvoicePayload({
      ...documento,
      registro: { ...documento.registro!, codigo_tipo_comprobante: '01', serie: 'F002', dias_credito: 30 },
      cuotas: [{ id: 1, numero_cuota: 1, monto: 118, fecha_vencimiento: '2026-12-17' }],
    }, empresa, cliente);
    expect(payload.formaPago).toEqual({ moneda: 'PEN', tipo: 'Credito', monto: 118 });
    expect(payload.cuotas).toHaveLength(1);
  });

  it('conserva las condiciones al crédito para el motivo 13', () => {
    const payload = mapper.mapComprobanteToInvoicePayload({
      ...documento,
      registro: { ...documento.registro!, codigo_motivo_nota: '13', dias_credito: 30 },
      cuotas: [{ id: 1, numero_cuota: 1, monto: 118, fecha_vencimiento: '2026-12-17' }],
    }, empresa, cliente);
    expect(payload.formaPago).toEqual({ moneda: 'PEN', tipo: 'Credito', monto: 118 });
    expect(payload.cuotas).toHaveLength(1);
  });

  it('requiere condiciones al crédito para el motivo 13', () => {
    expect(() => mapper.mapComprobanteToInvoicePayload({
      ...documento,
      registro: { ...documento.registro!, codigo_motivo_nota: '13' },
    }, empresa, cliente)).toThrow('motivo 13');
  });
});
