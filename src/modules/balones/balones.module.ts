import { Module } from '@nestjs/common';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';
import { BalonesController } from './controllers/balones.controller';
import { BalonesLogic } from './logic/balones.logic';
import { BalonesModel } from './models/balones.model';

@Module({
  imports: [NotificacionesModule],
  controllers: [BalonesController],
  providers: [BalonesLogic, BalonesModel],
})
export class BalonesModule {}
