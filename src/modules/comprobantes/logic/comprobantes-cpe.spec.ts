import { BadGatewayException } from '@nestjs/common';
import { ComprobantesLogic } from './comprobantes.logic';
import { FiltroComprobantesDto } from '../dto/comprobantes.dto';

describe('Protección del flujo de emisión y consulta CPE', () => {
  function setup() {
    const model = {
      reclamarEmision: jest.fn().mockResolvedValue({ ok: true, client: {} }),
      liberarEmisionLock: jest.fn().mockResolvedValue(undefined),
      obtenerCompleto: jest.fn().mockResolvedValue({ registro: {
        id: 69, serie: 'F001', numero: '00000023', codigo_tipo_comprobante: '01',
        fecha: '2026-10-12', total_importe: 330, id_cliente: 1, nombre_estado_sunat: 'PENDIENTE',
      } }),
      obtenerEmpresaEmisora: jest.fn().mockResolvedValue({ id: 1, ruc: '10175332796' }),
      resolverIdEstadoSunat: jest.fn().mockResolvedValue(123),
      registrarRespuestaSunat: jest.fn().mockResolvedValue({ registro: { id: 69 } }),
      listar: jest.fn().mockResolvedValue({ registros: [{ id: 68, nombre_estado_sunat: 'ACEPTADO' }], total: 1 }),
      evidenciasCdr: jest.fn().mockResolvedValue([{ id: 68, emision_en_curso: false, cdr_respuesta: JSON.stringify({ success: true, cdrResponse: { code: '2325' } }) }]),
      regularizar: jest.fn(),
      sincronizarValidez: jest.fn().mockResolvedValue(true),
    };
    const provider = {
      getConfigStatus: jest.fn().mockResolvedValue({ enabled: true, configured: true }),
      enviarFacturaBoleta: jest.fn().mockRejectedValue(new BadGatewayException('APIs Perú agotó el tiempo de espera de emisión; por confirmar')),
      consultarEstadoFacturaBoleta: jest.fn().mockResolvedValue({ success: false, error: { code: '0127' } }),
    };
    const validez = { consultar: jest.fn().mockResolvedValue({ codigo: '0', estado: 'NO INFORMADO' }) };
    const logic = Object.create(ComprobantesLogic.prototype) as ComprobantesLogic;
    Object.assign(logic, {
      model, facturacionClient: provider, validezClient: validez,
      clientesModel: { obtenerPorId: jest.fn().mockResolvedValue({ registro: { numero_documento: '20600000001', nombre_tipo_documento: 'RUC' } }) },
      invoiceMapper: { mapComprobanteToInvoicePayload: jest.fn().mockReturnValue({}) },
      logger: { warn: jest.fn() },
      notificarEmisionComprobante: jest.fn().mockResolvedValue(undefined),
    });
    return { logic, model, provider, validez };
  }
  beforeEach(() => { jest.useFakeTimers(); jest.setSystemTime(new Date('2026-10-12T16:00:00Z')); });
  afterEach(() => jest.useRealTimers());

  it('registra el timeout como pendiente, libera el bloqueo y no reintenta el envío', async () => {
    const { logic, model, provider } = setup();
    await expect(logic.emitir(69, { idUsuarioAuditoria: 1 })).rejects.toThrow('por confirmar');
    expect(provider.enviarFacturaBoleta).toHaveBeenCalledTimes(1);
    expect(model.registrarRespuestaSunat.mock.calls[0][1].cdrRespuesta).toContain('emision_por_confirmar');
    expect(model.resolverIdEstadoSunat).toHaveBeenCalledWith('PENDIENTE');
    expect(model.liberarEmisionLock).toHaveBeenCalledTimes(1);
  });

  it('rechaza la actualización del CDR cuando SUNAT no confirma fecha e importe', async () => {
    const { logic, model, provider } = setup();
    await expect(logic.consultarCdr(69, { idUsuarioAuditoria: 1 })).rejects.toThrow('fecha e importe');
    expect(model.registrarRespuestaSunat).not.toHaveBeenCalled();
    expect(provider.consultarEstadoFacturaBoleta).not.toHaveBeenCalled();
  });

  it('registra 2325 como rechazo aunque APIs Perú responda success true', async () => {
    const { logic, model, provider } = setup();
    provider.enviarFacturaBoleta.mockResolvedValue({ sunatResponse: { success: true, cdrResponse: { code: '2325' } } });
    const result = await logic.emitir(69, { idUsuarioAuditoria: 1 });
    expect(result.sunat.estado).toBe('RECHAZADO');
    expect(model.resolverIdEstadoSunat).toHaveBeenCalledWith('RECHAZADO');
  });

  it('no vuelve a enviar un correlativo que devuelve un CDR aceptado anterior', async () => {
    const { logic, model, provider } = setup();
    provider.consultarEstadoFacturaBoleta.mockResolvedValue({ sunatResponse: {
      success: true, cdrResponse: { code: '0', id: 'F001-0000023' },
    } });
    await expect(logic.emitir(69, { idUsuarioAuditoria: 1 })).rejects.toThrow('documento anterior');
    expect(provider.enviarFacturaBoleta).not.toHaveBeenCalled();
    expect(model.registrarRespuestaSunat).not.toHaveBeenCalled();
    expect(model.liberarEmisionLock).toHaveBeenCalledTimes(1);
  });

  it('no adjunta una constancia sin fecha verificable aunque la consulta de validez acepte', async () => {
    const { logic, model, provider, validez } = setup();
    validez.consultar.mockResolvedValue({ codigo: '1', estado: 'ACEPTADO' });
    provider.consultarEstadoFacturaBoleta.mockResolvedValue({ success: true, cdrResponse: { code: '0', id: 'F001-0000023' } });
    await expect(logic.consultarCdr(69, { idUsuarioAuditoria: 1 })).rejects.toThrow('no corresponde');
    expect(model.registrarRespuestaSunat).not.toHaveBeenCalled();
  });

  it('muestra evidencia de rechazo de los documentos antiguos sin cambiar los registros', async () => {
    const { logic, model } = setup();
    const result = await logic.listar(new FiltroComprobantesDto());
    expect(JSON.stringify(result)).toContain('Respuesta guardada del envío anterior (2325)');
    expect(model.registrarRespuestaSunat).not.toHaveBeenCalled();
  });

  it.each([
    [true, 'EN_CURSO'],
    [false, 'POR_CONFIRMAR'],
  ])('distingue una emisión activa de un timeout anterior: activa=%s', async (active, expected) => {
    const { logic, model } = setup();
    model.evidenciasCdr.mockResolvedValue([{ id: 68, emision_en_curso: active,
      cdr_respuesta: JSON.stringify({ tipo: 'emision_por_confirmar' }) }]);
    const result = await logic.listar(new FiltroComprobantesDto());
    expect(JSON.stringify(result)).toContain(expected);
    expect(model.registrarRespuestaSunat).not.toHaveBeenCalled();
  });

  it('no regulariza un comprobante que SUNAT reconoce como aceptado', async () => {
    const { logic, model, validez } = setup();
    validez.consultar.mockResolvedValue({ codigo: '1', estado: 'ACEPTADO' });
    await expect(logic.regularizar(69, 1)).rejects.toThrow('SUNAT respondió ACEPTADO');
    expect(model.regularizar).not.toHaveBeenCalled();
  });

  it('sincroniza únicamente la aceptación exacta sin enviar al proveedor', async () => {
    const { logic, model, provider, validez } = setup();
    const prueba = { codigo: '1', estado: 'ACEPTADO', consulta: { numeroSerie: 'F002', numero: 1, fechaEmision: '12/10/2026', monto: 330 } };
    validez.consultar.mockResolvedValue(prueba);
    const result = await logic.sincronizarValidez(69, 1);
    expect(result.estadoActualizado).toBe(true);
    expect(model.sincronizarValidez).toHaveBeenCalledWith(69, prueba, 1);
    expect(provider.enviarFacturaBoleta).not.toHaveBeenCalled();
    expect(model.registrarRespuestaSunat).not.toHaveBeenCalled();
  });

  it.each(['0', '2', '3', '4'])('no convierte el código %s en aceptación', async codigo => {
    const { logic, model, validez } = setup();
    validez.consultar.mockResolvedValue({ codigo, estado: 'OTRO' });
    expect((await logic.sincronizarValidez(69, 1)).estadoActualizado).toBe(false);
    expect(model.sincronizarValidez).not.toHaveBeenCalled();
  });

  it('deja de mostrar en curso si SUNAT ya confirmó aceptación, aunque el PSE siga esperando', async () => {
    const { logic, model } = setup();
    model.evidenciasCdr.mockResolvedValue([{ id: 68, emision_en_curso: true, validez_aceptada: true,
      cdr_respuesta: JSON.stringify({ tipo: 'emision_por_confirmar' }) }]);
    const result = await logic.listar(new FiltroComprobantesDto());
    expect(JSON.stringify(result)).not.toMatch(/EN_CURSO|POR_CONFIRMAR/);
    expect(JSON.stringify(result)).toContain('ACEPTADO');
  });

  it('devuelve aceptación cuando el timeout tardío fue superado por la consulta SUNAT', async () => {
    const { logic, model } = setup();
    model.registrarRespuestaSunat.mockResolvedValue({ registro: { id: 69, nombre_estado_sunat: 'ACEPTADO' } });
    expect((await logic.emitir(69, { idUsuarioAuditoria: 1 })).sunat.estado).toBe('ACEPTADO');
    expect(model.liberarEmisionLock).toHaveBeenCalledTimes(1);
  });

  it('continúa verificando una respuesta de emisión sin constancia confirmada', async () => {
    const { logic, model, provider } = setup();
    provider.enviarFacturaBoleta.mockResolvedValue({ sunatResponse: { success: true } });
    expect((await logic.emitir(69, { idUsuarioAuditoria: 1 })).sunat.estado).toBe('PENDIENTE');
    expect(JSON.parse(model.registrarRespuestaSunat.mock.calls[0][1].cdrRespuesta).tipo).toBe('emision_por_confirmar');
  });
});
