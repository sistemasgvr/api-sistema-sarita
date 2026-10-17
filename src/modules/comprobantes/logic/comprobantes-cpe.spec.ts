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
      guardarVerificacion: jest.fn().mockResolvedValue(true),
      reclamarOperacionCpe: jest.fn().mockResolvedValue('token-operacion'),
      liberarOperacionCpe: jest.fn().mockResolvedValue(undefined),
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

  it('bloquea la baja de un comprobante con cambios físicos antes de preparar una solicitud a SUNAT', async () => {
    const { logic, model, provider } = setup();
    const original = await model.obtenerCompleto();
    Object.assign(original.registro, { nombre_estado_sunat: 'ACEPTADO', tiene_cambio_fisico: true });
    model.obtenerCompleto.mockResolvedValue(original);
    await expect(logic.anular(69, { motivo: 'Prueba de devolución pendiente', idUsuarioAuditoria: 1 })).rejects.toThrow('cambios físicos');
    expect(model.obtenerEmpresaEmisora).not.toHaveBeenCalled();
    expect(provider.enviarFacturaBoleta).not.toHaveBeenCalled();
  });

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

  it('no convierte NO INFORMADO ni un error del proveedor en rechazo y no reenvía', async () => {
    const {logic,model,provider}=setup();
    model.evidenciasCdr.mockResolvedValue([{emision_en_curso:false}]);
    expect((await logic.verificarEnvio(69)).estado).toBe('SIN_CONFIRMACION');
    expect(model.guardarVerificacion.mock.calls[0][3]).toBeNull();
    expect(provider.consultarEstadoFacturaBoleta).toHaveBeenCalledTimes(1);
    expect(provider.enviarFacturaBoleta).not.toHaveBeenCalled();
  });

  it('no reenvía un resultado incierto aunque SUNAT responda NO INFORMADO', async()=>{
    const {logic,model,provider}=setup();
    const original=await model.obtenerCompleto(69);
    original.registro.cdr_respuesta=JSON.stringify({tipo:'emision_por_confirmar'});
    model.obtenerCompleto.mockResolvedValue(original);
    await expect(logic.emitir(69,{idUsuarioAuditoria:1})).rejects.toThrow('Verificar envío');
    expect(provider.enviarFacturaBoleta).not.toHaveBeenCalled();
    expect(model.liberarEmisionLock).toHaveBeenCalled();
  });

  it('reintenta un error HTTP solo después de comprobar SUNAT y ausencia de CDR, con la misma referencia',async()=>{
    const {logic,model,provider}=setup();
    const original=await model.obtenerCompleto(69);
    original.registro.cdr_respuesta=JSON.stringify({tipo:'emision_por_confirmar',sunatResponse:{success:false,error:{code:'HTTP',message:'Bad Request'}}});
    model.obtenerCompleto.mockResolvedValue(original);
    provider.enviarFacturaBoleta.mockResolvedValue({sunatResponse:{success:false,error:{code:'HTTP',message:'Bad Request'}}});
    const result=await logic.emitir(69,{idUsuarioAuditoria:1},true);
    expect(result.sunat.estado).toBe('ERROR_ENVIO');
    expect(provider.consultarEstadoFacturaBoleta).toHaveBeenCalledWith({ruc:'10175332796',tipo:'01',serie:'F001',numero:'23'});
    expect(provider.enviarFacturaBoleta).toHaveBeenCalledTimes(1);
    expect(model.regularizar).not.toHaveBeenCalled();
    expect(model.liberarOperacionCpe).toHaveBeenCalledWith(1,'token-operacion');
  });

  it('bloquea un reintento si el proveedor no confirma ausencia de CDR',async()=>{
    const {logic,model,provider}=setup();
    const original=await model.obtenerCompleto(69);
    original.registro.cdr_respuesta=JSON.stringify({tipo:'emision_por_confirmar',sunatResponse:{success:false,error:{code:'HTTP'}}});
    model.obtenerCompleto.mockResolvedValue(original);
    provider.consultarEstadoFacturaBoleta.mockResolvedValue({success:true});
    await expect(logic.emitir(69,{idUsuarioAuditoria:1},true)).rejects.toThrow('No se reintentó');
    expect(provider.enviarFacturaBoleta).not.toHaveBeenCalled();
  });

  it('no emite si otra operación de la empresa sigue activa',async()=>{
    const {logic,model,provider}=setup();
    model.reclamarOperacionCpe.mockResolvedValue(null);
    await expect(logic.emitir(69,{idUsuarioAuditoria:1})).rejects.toThrow('otra operación');
    expect(provider.enviarFacturaBoleta).not.toHaveBeenCalled();
    expect(model.liberarEmisionLock).toHaveBeenCalled();
  });

  it('habilita la acción manual únicamente para un error explícito con ambas consultas negativas',async()=>{
    const {logic,model}=setup();
    const original=await model.obtenerCompleto(69);
    original.registro.cdr_respuesta=JSON.stringify({tipo:'emision_por_confirmar',sunatResponse:{success:false,error:{code:'HTTP'}}});
    model.obtenerCompleto.mockResolvedValue(original);
    model.evidenciasCdr.mockResolvedValue([{emision_en_curso:false}]);
    const result=await logic.verificarEnvio(69);
    expect(result.estado).toBe('ERROR_ENVIO');
    expect(result.reintentoPermitido).toBe(true);
  });

  it('respeta una aceptación exacta de SUNAT y no consulta al proveedor después', async () => {
    const {logic,model,provider,validez}=setup();
    validez.consultar.mockResolvedValue({codigo:'1',estado:'ACEPTADO'});
    expect((await logic.verificarEnvio(69)).estado).toBe('ACEPTADO');
    expect(model.sincronizarValidez).toHaveBeenCalled();
    expect(provider.consultarEstadoFacturaBoleta).not.toHaveBeenCalled();
    expect(provider.enviarFacturaBoleta).not.toHaveBeenCalled();
  });

  it('conserva en curso mientras la petición sigue activa, sin consultar el CDR ni reenviar', async () => {
    const {logic,model,provider}=setup();
    model.evidenciasCdr.mockResolvedValue([{emision_en_curso:true}]);
    expect((await logic.verificarEnvio(69)).estado).toBe('EN_CURSO');
    expect(provider.consultarEstadoFacturaBoleta).not.toHaveBeenCalled();
    expect(provider.enviarFacturaBoleta).not.toHaveBeenCalled();
  });

  it('ignora un rechazo cuya constancia no se puede vincular al comprobante actual', async () => {
    const {logic,model,provider}=setup();
    model.evidenciasCdr.mockResolvedValue([{emision_en_curso:false}]);
    provider.consultarEstadoFacturaBoleta.mockResolvedValue({sunatResponse:{cdrResponse:{code:'2325'}}});
    expect((await logic.verificarEnvio(69)).estado).toBe('SIN_CONFIRMACION');
    expect(model.guardarVerificacion.mock.calls[0][3]).toBeNull();
  });

  it.each([['2325','RECHAZADO'],['0','SIN_CONFIRMACION']])('verifica también el código dentro del XML CDR: %s',async(codigoXml,expected)=>{
    const {logic,model,provider}=setup();
    model.evidenciasCdr.mockResolvedValue([{emision_en_curso:false}]);
    const name=Buffer.from('cdr.xml');
    const xml=Buffer.from('<cbc:ReferenceID>F001-23</cbc:ReferenceID><cbc:ResponseDate>2026-10-12</cbc:ResponseDate><cbc:ResponseCode>'+codigoXml+'</cbc:ResponseCode>');
    const local=Buffer.alloc(30); local.writeUInt32LE(0x04034b50,0); local.writeUInt16LE(name.length,26);
    const central=Buffer.alloc(46); central.writeUInt32LE(0x02014b50,0); central.writeUInt32LE(xml.length,20); central.writeUInt16LE(name.length,28);
    provider.consultarEstadoFacturaBoleta.mockResolvedValue({sunatResponse:{cdrResponse:{code:'2325'},cdrZip:Buffer.concat([local,name,xml,central,name]).toString('base64')}});
    expect((await logic.verificarEnvio(69)).estado).toBe(expected);
    expect(Boolean(model.guardarVerificacion.mock.calls[0][3])).toBe(expected==='RECHAZADO');
    expect(provider.enviarFacturaBoleta).not.toHaveBeenCalled();
  });
});
