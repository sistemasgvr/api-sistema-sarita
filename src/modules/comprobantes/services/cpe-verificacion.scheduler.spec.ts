import { CpeVerificacionScheduler } from './cpe-verificacion.scheduler';

describe('Verificación CPE independiente del navegador', () => {
  function setup() {
    const model={reclamarVerificacionGlobal:jest.fn().mockResolvedValue('token'),liberarVerificacionGlobal:jest.fn().mockResolvedValue(undefined),pendientesDeVerificacion:jest.fn().mockResolvedValue([{id:68},{id:67}])};
    const logic={verificarEnvio:jest.fn().mockResolvedValue({estado:'SIN_CONFIRMACION'})};
    return {model,logic,job:new CpeVerificacionScheduler(model as never,logic as never)};
  }
  it('verifica por turnos y libera el control aunque uno falle',async()=>{
    const {model,logic,job}=setup();
    logic.verificarEnvio.mockRejectedValueOnce(new Error('temporal'));
    await job.verificarPendientes();
    expect(logic.verificarEnvio.mock.calls).toEqual([[68],[67]]);
    expect(model.liberarVerificacionGlobal).toHaveBeenCalledWith('token');
  });
  it('no inicia otro ciclo si el anterior sigue en ejecución',async()=>{
    const {model,logic,job}=setup();
    let resolve!: (value: {estado:string})=>void;
    logic.verificarEnvio.mockImplementationOnce(()=>new Promise(done=>{resolve=done;}));
    const first=job.verificarPendientes();
    await Promise.resolve(); await Promise.resolve(); await Promise.resolve();
    await job.verificarPendientes();
    expect(model.reclamarVerificacionGlobal).toHaveBeenCalledTimes(1);
    resolve({estado:'SIN_CONFIRMACION'});
    await first;
  });
  it('no consulta documentos cuando otro proceso tiene el control',async()=>{
    const {model,logic,job}=setup();
    model.reclamarVerificacionGlobal.mockResolvedValue(null);
    await job.verificarPendientes();
    expect(logic.verificarEnvio).not.toHaveBeenCalled();
    expect(model.liberarVerificacionGlobal).not.toHaveBeenCalled();
  });
});
