import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { DocumentosSalidaLogic } from '../logic/documentos-salida.logic';

/**
 * Consulta en segundo plano los tickets GRE pendientes hasta un resultado
 * final. Cerrar el navegador no detiene la consulta; el ticket y cada
 * respuesta quedan en doc_gre_intento / doc_gre_consulta.
 */
@Injectable()
export class GreConsultaJob {
  private readonly logger = new Logger(GreConsultaJob.name);
  private enCurso = false;

  constructor(
    private readonly logic: DocumentosSalidaLogic,
    private readonly configService: ConfigService,
  ) {}

  @Cron(CronExpression.EVERY_5_MINUTES, { timeZone: 'America/Lima' })
  async ejecutar() {
    if (this.configService.get<boolean>('facturacion.greConsultaAutomatica') === false) return;
    // Una corrida a la vez por proceso; con varias APIs, cada intento tiene su
    // propia proxima_consulta y el estado nunca retrocede.
    if (this.enCurso) return;
    this.enCurso = true;
    try {
      const lote = this.configService.get<number>('facturacion.greConsultaLote') ?? 20;
      const resultado = await this.logic.consultarPendientes(lote);
      if (resultado.consultados > 0 || resultado.errores > 0) {
        this.logger.log(`Consulta automática GRE: ${JSON.stringify(resultado)}`);
      }
    } catch (error) {
      this.logger.error(`Consulta automática GRE falló: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      this.enCurso = false;
    }
  }
}
