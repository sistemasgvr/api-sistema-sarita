import { Module } from '@nestjs/common';
import { DireccionesController } from './controllers/direcciones.controller';
import { DireccionesLogic } from './logic/direcciones.logic';
import { DireccionesModel } from './models/direcciones.model';

@Module({
  controllers: [DireccionesController],
  providers: [DireccionesLogic, DireccionesModel],
})
export class DireccionesModule {}
