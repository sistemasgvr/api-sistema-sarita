import { Module } from '@nestjs/common';
import { LoginModule } from '../login/login.module';
import { NotificacionesController } from './controllers/notificaciones.controller';
import { NotificacionesGateway } from './gateways/notificaciones.gateway';
import { AlquileresVencidosJob } from './jobs/alquileres-vencidos.job';
import { NotificacionesLogic } from './logic/notificaciones.logic';
import { NotificacionesModel } from './models/notificaciones.model';

@Module({
  imports: [LoginModule],
  controllers: [NotificacionesController],
  providers: [
    NotificacionesModel,
    NotificacionesLogic,
    NotificacionesGateway,
    AlquileresVencidosJob,
  ],
  exports: [NotificacionesLogic, NotificacionesGateway],
})
export class NotificacionesModule {}
