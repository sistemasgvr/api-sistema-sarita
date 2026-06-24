import { Module } from '@nestjs/common';
import { EjemploController } from './controllers/ejemplo.controller';
import { EjemploLogic } from './logic/ejemplo.logic';
import { EjemploModel } from './models/ejemplo.model';

@Module({
  controllers: [EjemploController],
  providers: [EjemploLogic, EjemploModel],
})
export class EjemploModule {}
