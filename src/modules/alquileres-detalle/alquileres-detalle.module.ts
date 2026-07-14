import { Module } from '@nestjs/common';
import { AlquileresDetalleController } from './controllers/alquileres-detalle.controller';
import { AlquileresDetalleLogic } from './logic/alquileres-detalle.logic';
import { AlquileresDetalleModel } from './models/alquileres-detalle.model';

@Module({
  controllers: [AlquileresDetalleController],
  providers: [AlquileresDetalleLogic, AlquileresDetalleModel],
})
export class AlquileresDetalleModule {}
