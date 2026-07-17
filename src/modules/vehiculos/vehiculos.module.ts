import { Module } from '@nestjs/common';
import { VehiculosController } from './controllers/vehiculos.controller';
import { VehiculosLogic } from './logic/vehiculos.logic';
import { VehiculosModel } from './models/vehiculos.model';

@Module({
  controllers: [VehiculosController],
  providers: [VehiculosLogic, VehiculosModel],
  exports: [VehiculosLogic, VehiculosModel],
})
export class VehiculosModule {}
