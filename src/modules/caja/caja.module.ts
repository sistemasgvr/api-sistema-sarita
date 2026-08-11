import { Module } from '@nestjs/common';
import { CajaController } from './controllers/caja.controller';
import { CajaLogic } from './logic/caja.logic';
import { CajaModel } from './models/caja.model';

@Module({
  controllers: [CajaController],
  providers: [CajaLogic, CajaModel],
  exports: [CajaLogic, CajaModel],
})
export class CajaModule {}
