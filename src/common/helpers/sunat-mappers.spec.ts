import { RetencionMapper } from '../../modules/retenciones/mappers/retencion.mapper';
import { PercepcionMapper } from '../../modules/percepciones/mappers/percepcion.mapper';

const empresa = { ruc: ' 20 222222222 ', razon_social: ' Empresa ', nombre_comercial: null, direccion: ' Calle ', nombre_provincia: 'Chiclayo', nombre_departamento: 'Lambayeque', nombre_distrito: 'La Victoria', codigo_ubigeo: '140106' };
const tercero = { documento: ' 00 123456 ', nombre: ' Persona ', tipo_documento: 'Pasaporte' };

describe('Normalización de retención y percepción', () => {
  const retencion = new RetencionMapper();
  const percepcion = new PercepcionMapper();
  const cabecera = { serie: ' r001 ', numero: ' 000012 ', fecha_emision: '2026-10-07', regimen: '01', tasa: 3, detalles: [{ tipo_doc: ' 01 ', num_doc: ' f001-000123 ', moneda: ' pen ', fecha_emision: '2026-10-07', fecha_retencion: '2026-10-07', fecha_percepcion: '2026-10-07' }] };
  const enviar = [
    () => retencion.mapToRetentionPayload({ registro: cabecera } as unknown as Parameters<RetencionMapper['mapToRetentionPayload']>[0], empresa, tercero),
    () => percepcion.mapToPerceptionPayload({ registro: cabecera } as unknown as Parameters<PercepcionMapper['mapToPerceptionPayload']>[0], empresa, tercero),
  ];
  it.each(enviar)('normaliza identificadores y conserva el guion del comprobante relacionado', enviar => {
    expect(enviar()).toMatchObject({ serie: 'R001', correlativo: '12', company: { ruc: '20222222222' }, proveedor: { tipoDoc: '7', numDoc: '00123456', rznSocial: 'Persona' }, details: [{ tipoDoc: '01', numDoc: 'F001-000123', moneda: 'PEN' }] });
  });
  it('impide enviar NaN como correlativo', () => {
    expect(() => retencion.mapToRetentionPayload({ registro: { ...cabecera, numero: '12abc' } } as unknown as Parameters<RetencionMapper['mapToRetentionPayload']>[0], empresa, tercero)).toThrow('correlativo');
  });
});
