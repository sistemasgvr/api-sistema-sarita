import { BadRequestException, ConflictException } from '@nestjs/common';
import type { IntentoGrePendiente } from '../models/documentos-salida.model';
import { DocumentosSalidaLogic, proximaConsultaGre } from './documentos-salida.logic';

/**
 * La lógica se prueba con dobles: interesa el orden de las decisiones
 * (validar → verificar PSE → registrar intento → enviar) y que un envío
 * concurrente o un entorno cambiado no produzcan un segundo envío.
 */
function build(overrides: Record<string, unknown> = {}) {
  const registro = {
    id: 39, numero: 'OS-39', id_empresa: 18, nombre_estado_ciclo: 'GENERADA', nombre_estado_sunat: null,
    ticket_sunat: null, serie: 'T001', numero_sunat: '00000001', ...overrides,
  };
  const model = {
    obtener: jest.fn(() => Promise.resolve(({ registro }))),
    obtenerEmpresaEmisora: jest.fn(() => Promise.resolve(({ id: 18, ruc: '20222222222', razon_social: 'E', nombre_comercial: null, direccion: 'D', codigo_ubigeo: '020101' }))),
    iniciarIntentoGre: jest.fn(() => Promise.resolve(1)),
    guardarResultadoIntentoGre: jest.fn(() => Promise.resolve(undefined)),
    registrarRespuestaSunat: jest.fn(() => Promise.resolve(({ registro: { ...registro, nombre_estado_sunat: 'PENDIENTE' } }))),
    registrarConsultaGre: jest.fn(() => Promise.resolve(undefined)),
    obtenerUltimoIntentoGre: jest.fn<Promise<IntentoGrePendiente | null>, []>(() => Promise.resolve(null)),
    listarIntentosGrePendientesConsulta: jest.fn<Promise<IntentoGrePendiente[]>, []>(() => Promise.resolve([])),
    programarConsultaGre: jest.fn(() => Promise.resolve(undefined)),
  };
  const verificacion = { listo: true, entorno: 'beta', companyId: 5, problemas: [] as string[] };
  const client = {
    getConfigStatus: jest.fn(() => Promise.resolve(({ enabled: true, configured: true }))),
    verificarEmpresaGre: jest.fn(() => Promise.resolve(verificacion)),
    enviarGuiaRemision: jest.fn(() => Promise.resolve(({ hash: 'h', sunatResponse: { success: true, ticket: 't-1' } }))),
    consultarEstadoGuiaRemision: jest.fn<Promise<Record<string, unknown>>, [unknown]>(() => Promise.resolve({ success: true, code: '98' })),
  };
  const credentials = { withEmpresa: jest.fn((_id: number, op: () => Promise<unknown>) => op()) };
  const mapper = { mapToDespatchPayload: jest.fn(() => ({ company: { ruc: '20222222222' } })) };
  const notificaciones = { notificarPorPermiso: jest.fn(() => Promise.resolve(({ destinatarios: 1 }))), crearYEmitir: jest.fn() };
  const logic = new DocumentosSalidaLogic(
    model as never, client as never, credentials as never, mapper as never, {} as never, notificaciones as never,
  );
  return { logic, model, client, mapper, verificacion };
}

describe('Emisión GRE', () => {
  it('valida, verifica el PSE, registra el intento con entorno y recién entonces envía', async () => {
    const { logic, model, client, mapper } = build();
    const r = await logic.emitirSunat(39, { idUsuarioAuditoria: 1 });
    expect(mapper.mapToDespatchPayload).toHaveBeenCalled();
    expect(client.verificarEmpresaGre).toHaveBeenCalledWith('20222222222');
    expect(model.iniciarIntentoGre).toHaveBeenCalledWith(
      39, expect.anything(), expect.anything(),
      { idEmpresa: 18, rucEmisor: '20222222222', entorno: 'beta', idEmpresaPse: 5 }, 1,
    );
    const ordenIntento = model.iniciarIntentoGre.mock.invocationCallOrder[0];
    const ordenEnvio = client.enviarGuiaRemision.mock.invocationCallOrder[0];
    expect(ordenIntento).toBeLessThan(ordenEnvio);
    // success:true con ticket y sin CDR sigue pendiente, y se programa la consulta.
    expect(r.sunat.estado).toBe('PENDIENTE');
    expect(model.guardarResultadoIntentoGre).toHaveBeenLastCalledWith(1, 'PENDIENTE', expect.anything(), expect.any(Date));
  });

  it('no envía si la empresa no está lista en el PSE ni registra intento', async () => {
    const { logic, model, client, verificacion } = build();
    verificacion.listo = false;
    verificacion.problemas.push('client_id real en BETA');
    await expect(logic.emitirSunat(39, {})).rejects.toThrow('no está lista');
    expect(model.iniciarIntentoGre).not.toHaveBeenCalled();
    expect(client.enviarGuiaRemision).not.toHaveBeenCalled();
  });

  it('un segundo envío concurrente choca con el intento abierto y no llama al PSE', async () => {
    const { logic, model, client } = build();
    model.iniciarIntentoGre.mockRejectedValueOnce(new ConflictException('Existe un envío en curso'));
    await expect(logic.emitirSunat(39, {})).rejects.toThrow(ConflictException);
    expect(client.enviarGuiaRemision).not.toHaveBeenCalled();
  });

  it('bloquea documentos ya aceptados o con ticket pendiente', async () => {
    const aceptado = build({ nombre_estado_sunat: 'ACEPTADO' });
    await expect(aceptado.logic.emitirSunat(39, {})).rejects.toThrow('ya fue aceptado');
    const pendiente = build({ nombre_estado_sunat: 'PENDIENTE', ticket_sunat: 't-1' });
    await expect(pendiente.logic.emitirSunat(39, {})).rejects.toThrow('Consultar estado');
  });

  it('si el proveedor no responde, el intento queda por confirmar y no se reenvía', async () => {
    const { logic, model, client } = build();
    client.enviarGuiaRemision.mockRejectedValueOnce(new Error('timeout'));
    await expect(logic.emitirSunat(39, {})).rejects.toThrow('timeout');
    expect(model.guardarResultadoIntentoGre).toHaveBeenCalledWith(1, 'POR_CONFIRMAR', expect.anything());
    expect(client.enviarGuiaRemision).toHaveBeenCalledTimes(1);
  });
});

describe('Consulta de estado GRE', () => {
  it('consulta con el entorno del intento y rechaza si la empresa cambió de entorno', async () => {
    const { logic, model, client, verificacion } = build({ ticket_sunat: 't-1', nombre_estado_sunat: 'PENDIENTE' });
    model.obtenerUltimoIntentoGre.mockResolvedValue({ id: 1, id_doc_salida: 39, id_empresa: 18, entorno: 'beta', estado: 'PENDIENTE', ticket: 't-1', consultas: 0 });
    verificacion.entorno = 'produccion';
    await expect(logic.consultarEstado(39, {})).rejects.toThrow('BETA');
    expect(client.consultarEstadoGuiaRemision).not.toHaveBeenCalled();
  });

  it('ticket en proceso sigue pendiente y reprograma la consulta', async () => {
    const { logic, model, client } = build({ ticket_sunat: 't-1', nombre_estado_sunat: 'PENDIENTE' });
    model.obtenerUltimoIntentoGre.mockResolvedValue({ id: 1, id_doc_salida: 39, id_empresa: 18, entorno: 'beta', estado: 'PENDIENTE', ticket: 't-1', consultas: 2 });
    const r = await logic.consultarEstado(39, {});
    expect(client.consultarEstadoGuiaRemision).toHaveBeenCalledWith({ ticket: 't-1' });
    expect(r.sunat.estado).toBe('PENDIENTE');
    expect(model.registrarConsultaGre).toHaveBeenCalledWith(39, 'PENDIENTE', expect.anything(), expect.any(Date));
  });

  it('un CDR aceptado cierra el intento sin reprogramar', async () => {
    const { logic, model, client } = build({ ticket_sunat: 't-1', nombre_estado_sunat: 'PENDIENTE' });
    client.consultarEstadoGuiaRemision.mockResolvedValueOnce({ cdrResponse: { code: '0', description: 'ACEPTADA' } });
    const r = await logic.consultarEstado(39, {});
    expect(r.sunat.estado).toBe('ACEPTADO');
    expect(model.registrarConsultaGre).toHaveBeenCalledWith(39, 'ACEPTADO', expect.anything(), null);
  });

  it('sin ticket no consulta', async () => {
    const { logic } = build();
    await expect(logic.consultarEstado(39, {})).rejects.toThrow(BadRequestException);
  });

  it('la consulta automática reprograma los errores técnicos sin inventar rechazo', async () => {
    const { logic, model, client } = build({ ticket_sunat: 't-1', nombre_estado_sunat: 'PENDIENTE' });
    model.listarIntentosGrePendientesConsulta.mockResolvedValue([
      { id: 1, id_doc_salida: 39, id_empresa: 18, entorno: 'beta', estado: 'PENDIENTE', ticket: 't-1', consultas: 3 },
    ]);
    client.consultarEstadoGuiaRemision.mockRejectedValueOnce(new Error('PSE caído'));
    const r = await logic.consultarPendientes();
    expect(r).toEqual({ consultados: 0, aceptados: 0, rechazados: 0, pendientes: 0, errores: 1 });
    expect(model.programarConsultaGre).toHaveBeenCalledWith(1, expect.any(Date));
    expect(model.registrarRespuestaSunat).not.toHaveBeenCalled();
  });
});

describe('Espera progresiva', () => {
  it('crece con cada consulta y se estabiliza en un día', () => {
    const base = new Date('2026-09-16T12:00:00Z');
    const minutos = (n: number) => (proximaConsultaGre(n, base).getTime() - base.getTime()) / 60_000;
    expect([0, 1, 2, 7, 8, 50].map(minutos)).toEqual([2, 5, 15, 480, 1440, 1440]);
  });
});

describe('Visualización GRE sin cambiar la emisión', () => {
  const xml = '<?xml version="1.0"?><DespatchAdvice>original</DespatchAdvice>';
  const pdf = Buffer.from('%PDF-1.7\noriginal').toString('base64');
  function archivos() {
    const model = {
      obtener: jest.fn(async () => ({ registro: { id: 39, id_empresa: 18, serie: 'T001', numero_sunat: '1' } })),
      obtenerFuenteArchivosGre: jest.fn(async () => ({ id: 8, id_empresa: 18, entorno: 'beta', solicitud: { company: { ruc: '20222222222' }, fechaEmision: '2026-09-16' }, respuesta: { xml }, pdf_base64: null as string | null })),
      obtenerXmlHistoricoGre: jest.fn(async () => xml),
      guardarPdfGre: jest.fn(async () => undefined),
    };
    let empresaContexto: number | null = null;
    const creds = { withEmpresa: jest.fn(async (id: number, cb: () => Promise<unknown>) => { empresaContexto = id; try { return await cb(); } finally { empresaContexto = null; } }) };
    const client = {
      verificarEmpresaGre: jest.fn(async () => ({ entorno: 'beta' })),
      despatchPdf: jest.fn(async () => { expect(empresaContexto).toBe(18); return pdf; }),
      despatchXml: jest.fn(),
      enviarGuiaRemision: jest.fn(),
    };
    const logic = new DocumentosSalidaLogic(model as never, client as never, creds as never, {} as never, {} as never, {} as never);
    return { model, client, logic };
  }
  it('genera el PDF con snapshot y credenciales de la empresa original', async () => {
    const { model, client, logic } = archivos();
    const result = await logic.obtenerPdfOficial(39);
    expect(result.buffer.toString()).toContain('%PDF-');
    expect(client.despatchPdf).toHaveBeenCalledWith(expect.objectContaining({ fechaEmision: '2026-09-16' }));
    expect(model.guardarPdfGre).toHaveBeenCalledWith(8, pdf);
    expect(client.enviarGuiaRemision).not.toHaveBeenCalled();
  });
  it('devuelve el XML original sin regenerarlo ni contactar al PSE', async () => {
    const { client, logic } = archivos();
    expect((await logic.obtenerXmlOficial(39)).buffer.toString()).toBe(xml);
    expect(client.despatchXml).not.toHaveBeenCalled();
    expect(client.verificarEmpresaGre).not.toHaveBeenCalled();
  });
  it('impide generar el PDF en un entorno distinto al del envío', async () => {
    const { client, logic } = archivos();
    client.verificarEmpresaGre.mockResolvedValue({ entorno: 'produccion' });
    await expect(logic.obtenerPdfOficial(39)).rejects.toThrow('entorno');
    expect(client.despatchPdf).not.toHaveBeenCalled();
  });
  it('sirve PDF almacenado aunque el proveedor esté desconectado', async () => {
    const { model, client, logic } = archivos();
    const fuente = await model.obtenerFuenteArchivosGre();
    fuente.pdf_base64 = pdf;
    model.obtenerFuenteArchivosGre.mockResolvedValue(fuente);
    expect((await logic.obtenerPdfOficial(39)).buffer.toString()).toContain('%PDF-');
    expect(client.verificarEmpresaGre).not.toHaveBeenCalled();
  });
});
