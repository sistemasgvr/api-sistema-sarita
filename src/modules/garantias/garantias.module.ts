import { Module } from '@nestjs/common';
import { GarantiasController } from './controllers/garantias.controller';
import { GarantiasLogic } from './logic/garantias.logic';
import { GarantiasModel } from './models/garantias.model';

@Module({
  controllers: [GarantiasController],
  providers: [GarantiasLogic, GarantiasModel],
  exports: [GarantiasLogic],
})
export class GarantiasModule {}
