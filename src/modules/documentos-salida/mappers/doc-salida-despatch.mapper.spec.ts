import { DocSalidaDespatchMapper } from './doc-salida-despatch.mapper';
import type {
  DocumentoSalidaCompletoResult,
  DocumentoSalidaRegistro,
  EmpresaEmisora,
} from '../interfaces/documento-salida.interface';

const HOY = '2026-09-16';

const EMPRESA: EmpresaEmisora = {
  id: 18,
  ruc: '20222222222',
  razon_social: 'OXIGENO SARITA S.A.C.',
  nombre_comercial: 'Oxígeno Sarita',
  direccion: 'Jr. Los Pinos 123',
  id_distrito: 501,
  codigo_ubigeo: '020101',
  nombre_distrito: 'Huaraz',
  nombre_provincia: 'Huaraz',
  nombre_departamento: 'Ancash',
};

function fixture(overrides: Partial<DocumentoSalidaRegistro> = {}): DocumentoSalidaCompletoResult {
  return {
    registro: {
      codigo_tipo_guia: '09', numero_sunat: '00000001', serie: 'T001',
      codigo_modalidad_traslado: '02', codigo_motivo_traslado: '01', nombre_motivo_traslado: 'VENTA',
      ubigeo_origen: '150101', direccion_origen: 'Almacén central', ubigeo_llegada: '150102', direccion_llegada: 'Av. Cliente 1',
      placa_vehiculo: 'ANC-123', documento_chofer: '12345678', licencia_chofer: 'Q12345678',
      nombre_chofer: 'JUAN CARLOS PEREZ GOMEZ',
      nombres_chofer: 'JUAN CARLOS', apellido_paterno_chofer: 'PEREZ', apellido_materno_chofer: 'GOMEZ',
      fecha: '2026-09-11', fecha_emision_gre: HOY, fecha_traslado: HOY,
      documento_cliente: '20111111111', nombre_cliente: 'CLIENTE SAC', nombre_tipo_doc_cliente: 'RUC',
      peso_bruto: 12.5, numero_bultos: 2,
      detalle: [{ cantidad: 1, descripcion: 'Cilindro', codigo_unidad_medida: 'NIU' }],
      ...overrides,
    },
  } as unknown as DocumentoSalidaCompletoResult;
}

describe('GRE con chofer y vehículo', () => {
  const mapper = new DocSalidaDespatchMapper();

  it.each(['ANC-123', ' anc 123 ', 'ANC123'])('envía la placa %s sin separadores y conserva la licencia', (placa) => {
    const doc = fixture({ placa_vehiculo: placa });
    const result = mapper.mapToDespatchPayload(doc, EMPRESA, { hoy: HOY });
    expect(result.envio).toEqual(expect.objectContaining({
      modTraslado: '02',
      vehiculo: { placa: 'ANC123' },
      choferes: [expect.objectContaining({ licencia: 'Q12345678' })],
    }));
    expect(result.fechaEmision).toContain(HOY);
    expect(doc.registro?.placa_vehiculo).toBe(placa);
  });

  it('continúa rechazando choferes sin licencia', () => {
    const doc = fixture({ licencia_chofer: null });
    expect(() => mapper.mapToDespatchPayload(doc, EMPRESA, { hoy: HOY })).toThrow('licencia');
  });

  it('envía nombres y apellidos estructurados (nombres compuestos intactos)', () => {
    const result = mapper.mapToDespatchPayload(fixture(), EMPRESA, { hoy: HOY });
    expect((result.envio as { choferes: unknown[] }).choferes[0]).toEqual(
      expect.objectContaining({ nombres: 'JUAN CARLOS', apellidos: 'PEREZ GOMEZ' }),
    );
  });

  it('solo parte la cadena si no hay nombres estructurados', () => {
    const doc = fixture({ nombres_chofer: null, apellido_paterno_chofer: null, apellido_materno_chofer: null, nombre_chofer: 'MARIA LOPEZ' });
    const result = mapper.mapToDespatchPayload(doc, EMPRESA, { hoy: HOY });
    expect((result.envio as { choferes: unknown[] }).choferes[0]).toEqual(
      expect.objectContaining({ nombres: 'MARIA', apellidos: 'LOPEZ' }),
    );
  });
});

describe('Domicilio fiscal de la empresa emisora', () => {
  const mapper = new DocSalidaDespatchMapper();

  it('usa el ubigeo y los nombres reales de la empresa, sin valores fijos de Lima', () => {
    const result = mapper.mapToDespatchPayload(fixture(), EMPRESA, { hoy: HOY });
    expect(result.company).toEqual({
      ruc: '20222222222',
      razonSocial: 'OXIGENO SARITA S.A.C.',
      nombreComercial: 'Oxígeno Sarita',
      address: {
        direccion: 'Jr. Los Pinos 123',
        provincia: 'HUARAZ',
        departamento: 'ANCASH',
        distrito: 'HUARAZ',
        ubigueo: '020101',
      },
    });
  });

  it('no envía si la empresa no tiene distrito fiscal', () => {
    expect(() =>
      mapper.mapToDespatchPayload(fixture(), { ...EMPRESA, codigo_ubigeo: null }, { hoy: HOY }),
    ).toThrow('distrito fiscal');
  });
});

describe('Modalidades de transporte', () => {
  const mapper = new DocSalidaDespatchMapper();

  it('remitente con transporte público envía transportista y no vehículo', () => {
    const doc = fixture({
      codigo_modalidad_traslado: '01', documento_transportista: '20333333333', nombre_transportista: 'TRANSPORTES SAC',
      placa_vehiculo: null, documento_chofer: null, licencia_chofer: null, id_chofer: null,
    });
    const result = mapper.mapToDespatchPayload(doc, EMPRESA, { hoy: HOY });
    expect(result.envio).toEqual(expect.objectContaining({
      modTraslado: '01',
      transportista: { tipoDoc: '6', numDoc: '20333333333', rznSocial: 'TRANSPORTES SAC' },
    }));
    expect(result.envio).not.toHaveProperty('vehiculo');
    expect(result.envio).not.toHaveProperty('choferes');
  });

  it('GRE transportista (31) lleva flota propia y remitente aunque la modalidad guardada sea pública', () => {
    const doc = fixture({
      codigo_tipo_guia: '31', serie: 'V001', codigo_modalidad_traslado: '01',
      documento_destinatario: '20444444444', nombre_destinatario: 'DESTINO SAC', nombre_tipo_doc_destinatario: 'RUC',
    });
    const result = mapper.mapToDespatchPayload(doc, EMPRESA, { hoy: HOY });
    expect(result.tipoDoc).toBe('31');
    expect(result.envio).toEqual(expect.objectContaining({
      vehiculo: { placa: 'ANC123' },
      choferes: [expect.objectContaining({ nroDoc: '12345678' })],
    }));
    expect(result.envio).not.toHaveProperty('modTraslado');
    expect(result.envio).not.toHaveProperty('transportista');
    expect(result.remitente).toEqual({ tipoDoc: '6', numDoc: '20111111111', rznSocial: 'CLIENTE SAC' });
    expect(result.destinatario).toEqual(expect.objectContaining({ numDoc: '20444444444' }));
  });

  it('GRE transportista exige serie V', () => {
    const doc = fixture({ codigo_tipo_guia: '31', serie: 'T001', documento_destinatario: '20444444444' });
    expect(() => mapper.mapToDespatchPayload(doc, EMPRESA, { hoy: HOY })).toThrow('V001');
  });
});
