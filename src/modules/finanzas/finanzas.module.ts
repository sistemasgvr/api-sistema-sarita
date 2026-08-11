import { Module } from '@nestjs/common';
import { FinanzasController } from './controllers/finanzas.controller';
import { FinanzasLogic } from './logic/finanzas.logic';
import { FinanzasModel } from './models/finanzas.model';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';

@Module({
  imports: [NotificacionesModule],
  controllers: [FinanzasController],
  providers: [FinanzasLogic, FinanzasModel],
  exports: [FinanzasLogic, FinanzasModel],
})
export class FinanzasModule {}
