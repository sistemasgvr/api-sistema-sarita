import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { NotificacionesLogic } from '../logic/notificaciones.logic';

/** Detección diaria de alertas operativas (08:00 America/Lima). */
@Injectable()
export class AlquileresVencidosJob {
  private readonly logger = new Logger(AlquileresVencidosJob.name);

  constructor(private readonly notificacionesLogic: NotificacionesLogic) {}

  @Cron(CronExpression.EVERY_DAY_AT_8AM, { timeZone: 'America/Lima' })
  async ejecutarDiario() {
    this.logger.log('Job notificaciones diarias (08:00 America/Lima)');
    const resultados: Record<string, unknown> = {};

    for (const [clave, fn] of [
      ['alquileresVencidos', () => this.notificacionesLogic.detectarYNotificarAlquileresVencidos()],
      ['alquileresPorVencer', () => this.notificacionesLogic.detectarYNotificarAlquileresPorVencer()],
      ['prestamosVencidos', () => this.notificacionesLogic.detectarYNotificarPrestamosVencidos()],
      ['prestamosPorVencer', () => this.notificacionesLogic.detectarYNotificarPrestamosPorVencer()],
      ['stockBajo', () => this.notificacionesLogic.detectarYNotificarStockBajo()],
      ['documentosPorVencer', () => this.notificacionesLogic.detectarYNotificarDocumentosPorVencer()],
      ['documentosVencidos', () => this.notificacionesLogic.detectarYNotificarDocumentosVencidos()],
      ['licenciasPorVencer', () => this.notificacionesLogic.detectarYNotificarLicenciasPorVencer()],
      ['licenciasVencidas', () => this.notificacionesLogic.detectarYNotificarLicenciasVencidas()],
      [
        'comprobantesPendientesSunat',
        () => this.notificacionesLogic.detectarYNotificarComprobantesPendientesSunat(),
      ],
      [
        'guiasPendientesSunat',
        () => this.notificacionesLogic.detectarYNotificarGuiasPendientesSunat(),
      ],
      ['cajaSinCerrar', () => this.notificacionesLogic.detectarYNotificarCajaSinCerrar()],
    ] as const) {
      try {
        resultados[clave] = await fn();
      } catch (error) {
        resultados[clave] = {
          error: error instanceof Error ? error.message : String(error),
        };
        this.logger.error(
          `Job ${clave} falló: ${error instanceof Error ? error.message : error}`,
        );
      }
    }

    this.logger.log(`Job diario OK: ${JSON.stringify(resultados)}`);
  }
}
