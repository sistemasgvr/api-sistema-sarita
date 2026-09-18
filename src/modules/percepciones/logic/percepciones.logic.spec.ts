import { BadRequestException } from '@nestjs/common';
import { PercepcionesLogic } from './percepciones.logic';

/**
 * La lógica se prueba con dobles: interesa que la creación tome cliente,
 * importes y detalle de los comprobantes y que la emisión resuelva el estado
 * por evidencia (CDR), nunca por `success: true`.
 */
function build() {
  const comprobante = {
    id: 10, estado: 1, serie: 'F001', numero: '00000012', fecha: '2026-09-10', tipo_doc: '01',
    nombre_tipo_comprobante: 'FACTURA', total: '1180.00', moneda: 'PEN', id_cliente: 15,
    nombre_cliente: 'CLIENTE SAC', documento_cliente: '20100000141', nombre_estado_sunat: 'ACEPTADO', con_percepcion: false,
  };
  const registro = {
    id: 1, serie: 'P001', numero: '00000001', fecha_emision: '2026-09-17', id_empresa: 18, id_cliente: 15,
    regimen: '01', tasa: 2, base_imponible: 1180, monto_percibido: 23.6, monto_cobrado: 1203.6,
    nombre_estado_sunat: null as string | null, cdr_respuesta: null as string | null,
    detalles: [] as { id_comprobante: number; estado: number }[],
  };
  const model = {
    // La tasa sale del catálogo TasaPercepcion, asociada al régimen por su código.
    obtenerCatalogos: jest.fn(() => Promise.resolve({
      regimenesPercepcion: [{ id: 1, nombre: 'Percepción venta interna', descripcion: '01' }],
      tasasPercepcion: [{ id: 5, nombre: '2%', descripcion: '01' }],
      estadosSunat: [],
    })),
    obtenerComprobantes: jest.fn(() => Promise.resolve([comprobante])),
    crear: jest.fn(() => Promise.resolve({ id: 1, serie: 'P001', numero: '00000001' })),
    obtener: jest.fn(() => Promise.resolve({ registro })),
    registrarRespuestaSunat: jest.fn(() => Promise.resolve({ registro: { ...registro, nombre_estado_sunat: 'ACEPTADO' } })),
  };
  const db = {
    query: jest.fn((sql: string) => {
      if (sql.includes('FROM gen_empresa')) return Promise.resolve({ rows: [{ id: 18, ruc: '20615838650', razon_social: 'E', nombre_comercial: null, direccion: 'D', codigo_ubigeo: '140101' }] });
      if (sql.includes('FROM cli_clientes')) return Promise.resolve({ rows: [{ documento: '20100000141', nombre: 'CLIENTE SAC', tipo_documento: 'RUC' }] });
      if (sql.includes("'EstadoSunat'")) return Promise.resolve({ rows: [{ id: 127 }] });
      return Promise.resolve({ rows: [] });
    }),
  };
  const client = {
    getConfigStatus: jest.fn(() => Promise.resolve({ enabled: true, configured: true })),
    enviarPercepcion: jest.fn<Promise<{ sunatResponse: Record<string, unknown> }>, [unknown]>(() => Promise.resolve({ sunatResponse: { success: true } })),
  };
  const credentials = { withEmpresa: jest.fn((_id: number, op: () => Promise<unknown>) => op()) };
  const mapper = { mapToPerceptionPayload: jest.fn(() => ({ serie: 'P001' })) };
  const logic = new PercepcionesLogic(model as never, db as never, client as never, credentials as never, mapper as never);
  return { logic, model, client, credentials };
}

describe('Creación de percepción desde comprobantes', () => {
  it('arma cliente, sucursal, importes y detalle desde el comprobante aceptado', async () => {
    const { logic, model } = build();
    const r = await logic.crear({ idEmpresa: 18, serie: 'P001', fechaEmision: '2026-09-17', regimen: '01', comprobantes: [{ idComprobante: 10 }] }, 1);
    expect(r).toEqual({ id: 1, serie: 'P001', numero: '00000001' });
    expect(model.crear).toHaveBeenCalledWith(expect.objectContaining({
      idCliente: 15, tasa: 2, baseImponible: 1180, montoPercibido: 23.6, montoCobrado: 1203.6, idUsuarioAuditoria: 1,
      detalles: [expect.objectContaining({ id_comprobante: 10, num_doc: 'F001-00000012', imp_percibido: 23.6, imp_cobrar: 1203.6, fecha_percepcion: '2026-09-17' })],
    }));
  });

  it('rechaza régimen inexistente, tasa ajena al régimen y comprobantes rechazados por SUNAT sin llamar a la BD de escritura', async () => {
    const { logic, model } = build();
    await expect(logic.crear({ idEmpresa: 18, serie: 'P001', fechaEmision: '2026-09-17', regimen: '77', comprobantes: [{ idComprobante: 10 }] }))
      .rejects.toThrow(BadRequestException);
    await expect(logic.crear({ idEmpresa: 18, serie: 'P001', fechaEmision: '2026-09-17', regimen: '01', tasa: 7, comprobantes: [{ idComprobante: 10 }] }))
      .rejects.toThrow('no está registrada para el régimen');
    model.obtenerComprobantes.mockResolvedValueOnce([{ ...(await model.obtenerComprobantes())[0], nombre_estado_sunat: 'RECHAZADO' }]);
    await expect(logic.crear({ idEmpresa: 18, serie: 'P001', fechaEmision: '2026-09-17', regimen: '01', comprobantes: [{ idComprobante: 10 }] }))
      .rejects.toThrow('está RECHAZADO ante SUNAT');
    expect(model.crear).not.toHaveBeenCalled();
  });

  it('acepta comprobantes aún pendientes de envío: la percepción se arma al cobrar', async () => {
    const { logic, model } = build();
    model.obtenerComprobantes.mockResolvedValueOnce([{ ...(await model.obtenerComprobantes())[0], nombre_estado_sunat: 'PENDIENTE' }]);
    await expect(logic.crear({ idEmpresa: 18, serie: 'P001', fechaEmision: '2026-09-17', regimen: '01', comprobantes: [{ idComprobante: 10 }] }))
      .resolves.toEqual({ id: 1, serie: 'P001', numero: '00000001' });
  });
});

describe('Emisión de percepción', () => {
  it('success:true sin CDR queda PENDIENTE y con CDR aceptado pasa a ACEPTADO', async () => {
    const { logic, model, client, credentials } = build();
    const pendiente = await logic.emitir(1, {});
    expect(pendiente.sunat.estado).toBe('PENDIENTE');
    expect(credentials.withEmpresa).toHaveBeenCalledWith(18, expect.any(Function));

    client.enviarPercepcion.mockResolvedValueOnce({ sunatResponse: { success: true, cdrResponse: { code: '0' } } });
    const aceptada = await logic.emitir(1, {});
    expect(aceptada.sunat.estado).toBe('ACEPTADO');
    expect(model.registrarRespuestaSunat).toHaveBeenLastCalledWith(1, expect.objectContaining({ idEstadoSunat: 127 }));
  });

  it('no emite mientras algún comprobante de origen siga sin aceptar', async () => {
    const { logic, model, client } = build();
    const base = (await model.obtener()).registro;
    model.obtener.mockResolvedValueOnce({ registro: { ...base, detalles: [{ id_comprobante: 10, estado: 1 }] } });
    model.obtenerComprobantes.mockResolvedValueOnce([{ ...(await model.obtenerComprobantes())[0], nombre_estado_sunat: 'PENDIENTE' }]);
    await expect(logic.emitir(1, {})).rejects.toThrow('Emite primero a SUNAT los comprobantes de la percepción: F001-00000012 (PENDIENTE)');
    expect(client.enviarPercepcion).not.toHaveBeenCalled();
  });

  it('no reemite una percepción aceptada', async () => {
    const { logic, model, client } = build();
    model.obtener.mockResolvedValueOnce({ registro: { ...(await model.obtener()).registro, nombre_estado_sunat: 'ACEPTADO' } });
    await expect(logic.emitir(1, {})).rejects.toThrow('ya fue aceptada');
    expect(client.enviarPercepcion).not.toHaveBeenCalled();
  });
});
