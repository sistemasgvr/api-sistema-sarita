import { Module } from '@nestjs/common';
import { FinanzasController } from './controllers/finanzas.controller';
import { FinanzasLogic } from './logic/finanzas.logic';
import { FinanzasModel } from './models/finanzas.model';

@Module({
  controllers: [FinanzasController],
  providers: [FinanzasLogic, FinanzasModel],
  exports: [FinanzasLogic, FinanzasModel],
})
export class FinanzasModule {}
