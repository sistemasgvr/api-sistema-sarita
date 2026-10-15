import { ComprobanteInvoiceMapper } from './comprobante-invoice.mapper';
import type { ComprobanteCompletoResult } from '../interfaces/comprobante.interface';

const empresa = { ruc: ' 20 222222222 ', razon_social: ' Empresa ', direccion: ' Calle Los Andes ', codigo_ubigeo: '140106', nombre_distrito: 'La Victoria', nombre_provincia: 'Chiclayo', nombre_departamento: 'Lambayeque' };
const cliente = { nombre_tipo_documento: 'Carné de extranjería', numero_documento: '00 123456', razon_social: ' Cliente ' };
function documento(numero = ' 000012 ', fecha = '2026-10-07'): ComprobanteCompletoResult {
  return { registro: { codigo_tipo_comprobante: ' 03 ', serie: ' b001 ', numero, fecha, codigo_moneda: ' pen ' }, detalles: [{ cantidad: 1, valor_venta: 10, impuesto: 1.8, importe: 11.8, descripcion: 'Oxígeno', codigo_afectacion_igv: '10' }] } as unknown as ComprobanteCompletoResult;
}

describe('Invoice: normalización y domicilio real', () => {
  const mapper = new ComprobanteInvoiceMapper();
  it.each([
    [' EL ENVASE Y5204092 SE DA EN CALIDAD DE PRESTAMO ', null, 'EL ENVASE Y5204092 SE DA EN CALIDAD DE PRESTAMO'],
    ['Envase en préstamo', 'Nota interna confidencial', 'Envase en préstamo'],
    [null, 'Nota interna confidencial', undefined],
    [' Misma nota ', 'Misma nota', 'Misma nota'],
    ['  ', 'Nota interna confidencial', undefined],
  ])('envía solo la glosa y excluye observaciones internas: %s / %s', (glosa, observaciones, esperado) => {
    const doc = documento();
    Object.assign(doc.registro!, { glosa, observaciones });
    const payload = mapper.mapComprobanteToInvoicePayload(doc, empresa, cliente);
    expect(payload.observacion).toBe(esperado);
    expect(payload).not.toHaveProperty('observaciones');
    expect(JSON.stringify(payload)).not.toContain('Nota interna confidencial');
    expect(payload.details).toEqual(expect.arrayContaining([expect.objectContaining({ descripcion: 'Oxígeno' })]));
    expect(payload.mtoImpVenta).toBe(11.8);
  });
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
  it('envía las cuotas en la raíz y el importe neto en formaPago según el contrato de APIs Perú', () => {
    const doc=documento('23','2026-10-05');
    Object.assign(doc.registro!,{fecha_emision_cpe:'2026-10-12',dias_credito:30,fecha_vencimiento:'2026-11-05'});
    const payload=mapper.mapComprobanteToInvoicePayload(doc,empresa,cliente);
    expect(payload.formaPago).toEqual({moneda:'PEN',tipo:'Credito',monto:11.8});
    expect(payload.cuotas).toEqual([{moneda:'PEN',monto:11.8,fechaPago:'2026-11-05T00:00:00-05:00'}]);
    expect((payload.formaPago as Record<string,unknown>).cuotas).toBeUndefined();
  });
  it('conserva el importe y vencimiento de cada cuota almacenada', () => {
    const doc=documento();
    doc.cuotas=[{monto:5,fecha_vencimiento:'2026-11-01'},{monto:6.8,fecha_vencimiento:'2026-12-01'}] as never;
    const payload=mapper.mapComprobanteToInvoicePayload(doc,empresa,cliente);
    expect(payload.formaPago).toEqual({moneda:'PEN',tipo:'Credito',monto:11.8});
    expect(payload.cuotas).toEqual([{moneda:'PEN',monto:5,fechaPago:'2026-11-01T00:00:00-05:00'},{moneda:'PEN',monto:6.8,fechaPago:'2026-12-01T00:00:00-05:00'}]);
  });
  it('no convierte una venta al contado en crédito', () => {
    const payload=mapper.mapComprobanteToInvoicePayload(documento(),empresa,cliente);
    expect(payload.formaPago).toEqual({moneda:'PEN',tipo:'Contado'});expect(payload.cuotas).toBeUndefined();
  });
  it('bloquea una cuota vencida antes de la fecha fiscal sin inventar otro vencimiento', () => {
    const doc=documento('23','2026-10-05');
    Object.assign(doc.registro!,{fecha_emision_cpe:'2026-10-12',dias_credito:30,fecha_vencimiento:'2026-10-06'});
    expect(()=>mapper.mapComprobanteToInvoicePayload(doc,empresa,cliente)).toThrow('Revisa las cuotas');
  });
});
