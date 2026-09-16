import { hoyLima, nombresChofer, normalizarPlaca, soloErrores, validarGre } from './gre-validacion';
import type { DocumentoSalidaRegistro, EmpresaEmisora } from '../interfaces/documento-salida.interface';

const HOY = '2026-09-16';

const EMPRESA: EmpresaEmisora = {
  id: 18, ruc: '20222222222', razon_social: 'OXIGENO SARITA S.A.C.', nombre_comercial: null,
  direccion: 'Jr. Los Pinos 123', id_distrito: 501, codigo_ubigeo: '020101',
  nombre_distrito: 'Huaraz', nombre_provincia: 'Huaraz', nombre_departamento: 'Ancash',
};

function cabecera(overrides: Partial<DocumentoSalidaRegistro> = {}): DocumentoSalidaRegistro {
  return {
    codigo_tipo_guia: '09', numero_sunat: '00000001', serie: 'T001',
    codigo_modalidad_traslado: '02', codigo_motivo_traslado: '01',
    ubigeo_origen: '150101', direccion_origen: 'Almacén', ubigeo_llegada: '150102', direccion_llegada: 'Av. 1',
    placa_vehiculo: 'ANC-123', id_chofer: 7, documento_chofer: '12345678', licencia_chofer: 'Q12345678',
    licencia_chofer_vencimiento: '2027-01-01',
    nombre_chofer: 'JUAN CARLOS PEREZ GOMEZ', nombres_chofer: 'JUAN CARLOS', apellido_paterno_chofer: 'PEREZ', apellido_materno_chofer: 'GOMEZ',
    fecha: '2026-09-11', fecha_emision_gre: HOY, fecha_traslado: HOY,
    documento_cliente: '20111111111', nombre_cliente: 'CLIENTE SAC',
    peso_bruto: 12.5, numero_bultos: 1,
    detalle: [{ cantidad: 1, descripcion: 'Cilindro' }],
    ...overrides,
  } as unknown as DocumentoSalidaRegistro;
}

const codigos = (c: DocumentoSalidaRegistro, e: EmpresaEmisora | null = EMPRESA) =>
  validarGre(c, e, { hoy: HOY }).map((p) => `${p.severidad}:${p.codigo}`);

describe('Prevalidación GRE', () => {
  it('una guía completa queda lista para emitir', () => {
    expect(validarGre(cabecera(), EMPRESA, { hoy: HOY })).toEqual([]);
  });

  it('exige empresa emisora con RUC, razón social, dirección y ubigeo reales', () => {
    expect(codigos(cabecera(), null)).toEqual(['error:EMPRESA_AUSENTE']);
    expect(codigos(cabecera(), { ...EMPRESA, codigo_ubigeo: null })).toEqual(['error:EMPRESA_UBIGEO']);
    expect(codigos(cabecera(), { ...EMPRESA, ruc: '123', direccion: '' })).toEqual(
      expect.arrayContaining(['error:EMPRESA_RUC', 'error:EMPRESA_DIRECCION']),
    );
  });

  it('fechas: emisión propia de la GRE, no la de la orden', () => {
    expect(codigos(cabecera({ fecha_emision_gre: null }))).toContain('error:FECHA_EMISION');
    expect(codigos(cabecera({ fecha_emision_gre: '2026-09-17' }))).toContain('error:FECHA_EMISION_FUTURA');
    // Orden antigua con GRE fechada hoy: válida, sin heredar la fecha de la orden.
    expect(codigos(cabecera({ fecha: '2026-09-01' }))).toEqual([]);
    // Fecha anterior a hoy: se advierte (rechazo 2108 visto en la prueba), no se bloquea.
    expect(codigos(cabecera({ fecha_emision_gre: '2026-09-11' }))).toEqual(['advertencia:FECHA_EMISION_ANTERIOR']);
    expect(codigos(cabecera({ fecha_traslado: '2026-09-15' }))).toContain('error:FECHA_TRASLADO_ANTERIOR');
  });

  it('serie coherente con el tipo de guía', () => {
    expect(codigos(cabecera({ serie: 'V001' }))).toContain('error:SERIE_TIPO');
    expect(codigos(cabecera({ codigo_tipo_guia: '31', serie: 'V001', documento_destinatario: '20444444444' }))).toEqual([]);
    expect(codigos(cabecera({ codigo_tipo_guia: '31', serie: 'T001', documento_destinatario: '20444444444' }))).toContain('error:SERIE_TIPO');
  });

  it('chofer: distingue sin licencia, vencida y nombres derivados', () => {
    expect(codigos(cabecera({ licencia_chofer: null }))).toEqual(['error:CHOFER_LICENCIA']);
    expect(codigos(cabecera({ licencia_chofer_vencimiento: '2026-09-15' }))).toEqual(['error:CHOFER_LICENCIA_VENCIDA']);
    expect(codigos(cabecera({ nombres_chofer: null, apellido_paterno_chofer: null }))).toEqual(['advertencia:CHOFER_NOMBRES_DERIVADOS']);
    expect(codigos(cabecera({ nombres_chofer: null, apellido_paterno_chofer: null, nombre_chofer: '' }))).toEqual(['error:CHOFER_NOMBRES']);
  });

  it('placa: normaliza para el envío y valida el formato', () => {
    expect(normalizarPlaca('ANC-123')).toBe('ANC123');
    expect(codigos(cabecera({ placa_vehiculo: 'A-1' }))).toEqual(['error:PLACA_FORMATO']);
    expect(codigos(cabecera({ placa_vehiculo: null }))).toEqual(['error:PLACA']);
  });

  it('transporte público exige RUC del transportista y no chofer', () => {
    const publico = cabecera({
      codigo_modalidad_traslado: '01', placa_vehiculo: null, id_chofer: null, documento_chofer: null, licencia_chofer: null,
      documento_transportista: '20333333333', nombre_transportista: 'TRANSPORTES SAC',
    });
    expect(codigos(publico)).toEqual([]);
    expect(codigos({ ...publico, documento_transportista: '123' })).toEqual(['error:TRANSPORTISTA_RUC']);
  });

  it('GRE transportista (31) es flota propia y exige remitente', () => {
    const base = cabecera({ codigo_tipo_guia: '31', serie: 'V001', codigo_modalidad_traslado: '01', documento_destinatario: '20444444444' });
    expect(codigos(base)).toEqual([]);
    expect(codigos({ ...base, placa_vehiculo: null })).toContain('error:PLACA');
    expect(codigos({ ...base, documento_cliente: null })).toContain('error:REMITENTE_DOC');
  });

  it('bienes y destino', () => {
    expect(codigos(cabecera({ detalle: [] }))).toEqual(['error:SIN_ITEMS']);
    expect(codigos(cabecera({ detalle: [{ cantidad: 0, descripcion: '' }] as never }))).toEqual(
      expect.arrayContaining(['error:ITEM_CANTIDAD', 'error:ITEM_DESCRIPCION']),
    );
    expect(codigos(cabecera({ peso_bruto: 0 }))).toEqual(['error:PESO']);
    expect(codigos(cabecera({ ubigeo_llegada: '15' }))).toEqual(['error:LLEGADA_UBIGEO']);
    expect(codigos(cabecera({ documento_cliente: null }))).toEqual(['error:DESTINATARIO_DOC']);
  });

  it('soloErrores descarta advertencias', () => {
    const problemas = validarGre(cabecera({ fecha_emision_gre: '2026-09-11' }), EMPRESA, { hoy: HOY });
    expect(problemas).toHaveLength(1);
    expect(soloErrores(problemas)).toEqual([]);
  });

  it('hoyLima usa la fecha civil de Perú', () => {
    expect(hoyLima(new Date('2026-09-17T03:00:00Z'))).toBe('2026-09-16');
    expect(hoyLima(new Date('2026-09-17T05:00:00Z'))).toBe('2026-09-17');
  });

  it('nombresChofer prefiere los campos estructurados', () => {
    expect(nombresChofer({ nombres_chofer: 'ANA MARIA', apellido_paterno_chofer: 'DE LA CRUZ', apellido_materno_chofer: 'RIOS', nombre_chofer: 'x' }))
      .toEqual({ nombres: 'ANA MARIA', apellidos: 'DE LA CRUZ RIOS', estructurado: true });
    expect(nombresChofer({ nombre_chofer: 'SOLO' })).toEqual({ nombres: 'SOLO', apellidos: 'SOLO', estructurado: false });
  });
});
