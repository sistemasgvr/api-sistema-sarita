import { Module } from '@nestjs/common';
import { SesionesController } from './controllers/sesiones.controller';
import { SesionesLogic } from './logic/sesiones.logic';
import { SesionesModel } from './models/sesiones.model';

@Module({
  controllers: [SesionesController],
  providers: [SesionesLogic, SesionesModel],
})
export class SesionesModule {}
