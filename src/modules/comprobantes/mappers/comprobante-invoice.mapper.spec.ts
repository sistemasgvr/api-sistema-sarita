import { ComprobanteInvoiceMapper } from './comprobante-invoice.mapper';
import type { ComprobanteCompletoResult } from '../interfaces/comprobante.interface';

const empresa = { ruc: ' 20 222222222 ', razon_social: ' Empresa ', direccion: ' Calle Los Andes ', codigo_ubigeo: '140106', nombre_distrito: 'La Victoria', nombre_provincia: 'Chiclayo', nombre_departamento: 'Lambayeque' };
const cliente = { nombre_tipo_documento: 'Carné de extranjería', numero_documento: '00 123456', razon_social: ' Cliente ' };
function documento(numero = ' 000012 ', fecha = '2026-10-07'): ComprobanteCompletoResult {
  return { registro: { codigo_tipo_comprobante: ' 03 ', serie: ' b001 ', numero, fecha, codigo_moneda: ' pen ' }, detalles: [{ cantidad: 1, valor_venta: 10, impuesto: 1.8, importe: 11.8, descripcion: 'Oxígeno', codigo_afectacion_igv: '10' }] } as unknown as ComprobanteCompletoResult;
}

describe('Invoice: normalización y domicilio real', () => {
  const mapper = new ComprobanteInvoiceMapper();
  it('respeta el tipo del receptor y la dirección fiscal registrada', () => {
    const payload = mapper.mapComprobanteToInvoicePayload(documento(), empresa, cliente);
    expect(payload).toMatchObject({ tipoDoc: '03', serie: 'B001', correlativo: '12', tipoMoneda: 'PEN', client: { tipoDoc: '4', numDoc: '00123456' }, company: { ruc: '20222222222', razonSocial: 'Empresa', address: { ubigueo: '140106', distrito: 'LA VICTORIA', provincia: 'CHICLAYO', departamento: 'LAMBAYEQUE' } } });
    expect((payload.client as { address: { ubigueo?: string } }).address.ubigueo).toBeUndefined();
  });
  it.each([['12abc', '2026-10-07'], ['12', '2026-02-30']])('bloquea número %s o fecha %s inválidos', (numero, fecha) => {
    expect(() => mapper.mapComprobanteToInvoicePayload(documento(numero, fecha), empresa, cliente)).toThrow();
  });
  it('pide completar el distrito fiscal en lugar de reemplazarlo por Lima', () => {
    expect(() => mapper.mapComprobanteToInvoicePayload(documento(), { ...empresa, codigo_ubigeo: null }, cliente)).toThrow('distrito fiscal');
  });
});
