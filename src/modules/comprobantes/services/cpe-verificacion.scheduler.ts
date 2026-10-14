import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { ComprobantesLogic } from '../logic/comprobantes.logic';
import { ComprobantesModel } from '../models/comprobantes.model';

@Injectable()
export class CpeVerificacionScheduler {
  private ejecutando = false;
  private readonly logger = new Logger(CpeVerificacionScheduler.name);
  constructor(private readonly model: ComprobantesModel, private readonly logic: ComprobantesLogic) {}

  @Interval(30000)
  async verificarPendientes() {
    if (this.ejecutando) return;
    this.ejecutando=true;
    let lock: Awaited<ReturnType<ComprobantesModel['reclamarVerificacionGlobal']>> = null;
    try {
      lock = await this.model.reclamarVerificacionGlobal();
      if (!lock) return;
      const pendientes = await this.model.pendientesDeVerificacion();
      for (const doc of pendientes) {
        try { await this.logic.verificarEnvio(doc.id); }
        catch { this.logger.warn('No se pudo verificar el comprobante '+doc.id+'; se consultará nuevamente.'); }
      }
    } catch { this.logger.warn('Verificación CPE temporalmente no disponible; se retomará en el siguiente ciclo.'); }
    finally {
      try { if (lock) await this.model.liberarVerificacionGlobal(lock); }
      finally { this.ejecutando=false; }
    }
  }
}
