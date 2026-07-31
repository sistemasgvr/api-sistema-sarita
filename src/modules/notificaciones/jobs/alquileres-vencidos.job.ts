import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { NotificacionesLogic } from '../logic/notificaciones.logic';

@Injectable()
export class AlquileresVencidosJob {
  private readonly logger = new Logger(AlquileresVencidosJob.name);

  constructor(private readonly notificacionesLogic: NotificacionesLogic) {}

  @Cron(CronExpression.EVERY_DAY_AT_8AM, { timeZone: 'America/Lima' })
  async ejecutarDiario() {
    this.logger.log('Job alquileres vencidos (diario 08:00 America/Lima)');
    try {
      const result =
        await this.notificacionesLogic.detectarYNotificarAlquileresVencidos();
      this.logger.log(`Job OK: ${JSON.stringify(result)}`);
    } catch (error) {
      this.logger.error(
        `Job falló: ${error instanceof Error ? error.message : error}`,
      );
    }
  }
}
