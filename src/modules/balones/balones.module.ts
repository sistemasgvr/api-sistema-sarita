import { Module } from '@nestjs/common';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';
import { BalonesController } from './controllers/balones.controller';
import { BalonesLogic } from './logic/balones.logic';
import { BalonesModel } from './models/balones.model';
import { BalonEtiquetaPdfGenerator } from './services/balon-etiqueta-pdf.generator';

@Module({
  imports: [NotificacionesModule],
  controllers: [BalonesController],
  providers: [BalonesLogic, BalonesModel, BalonEtiquetaPdfGenerator],
})
export class BalonesModule {}
