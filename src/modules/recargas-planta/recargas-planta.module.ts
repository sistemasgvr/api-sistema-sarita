import { Module } from '@nestjs/common';
import { RecargasPlantaController } from './controllers/recargas-planta.controller';
import { RecargasPlantaLogic } from './logic/recargas-planta.logic';
import { RecargasPlantaModel } from './models/recargas-planta.model';

@Module({
  controllers: [RecargasPlantaController],
  providers: [RecargasPlantaLogic, RecargasPlantaModel],
})
export class RecargasPlantaModule {}
