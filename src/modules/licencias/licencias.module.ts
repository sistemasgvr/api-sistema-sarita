import { Module } from '@nestjs/common';
import { LicenciasController } from './controllers/licencias.controller';
import { LicenciasLogic } from './logic/licencias.logic';
import { LicenciasModel } from './models/licencias.model';

@Module({
  controllers: [LicenciasController],
  providers: [LicenciasLogic, LicenciasModel],
  exports: [LicenciasLogic, LicenciasModel],
})
export class LicenciasModule {}
