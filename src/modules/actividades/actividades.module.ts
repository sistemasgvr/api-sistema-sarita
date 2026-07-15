import { Module } from '@nestjs/common';
import { ActividadesController } from './controllers/actividades.controller';
import { ActividadesLogic } from './logic/actividades.logic';
import { ActividadesModel } from './models/actividades.model';

@Module({
  controllers: [ActividadesController],
  providers: [ActividadesLogic, ActividadesModel],
})
export class ActividadesModule {}