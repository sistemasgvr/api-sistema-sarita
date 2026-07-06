import { Module } from '@nestjs/common';
import { PrestamosDetalleController } from './controllers/prestamos-detalle.controller';
import { PrestamosDetalleLogic } from './logic/prestamos-detalle.logic';
import { PrestamosDetalleModel } from './models/prestamos-detalle.model';

@Module({
  controllers: [PrestamosDetalleController],
  providers: [PrestamosDetalleLogic, PrestamosDetalleModel],
})
export class PrestamosDetalleModule {}
