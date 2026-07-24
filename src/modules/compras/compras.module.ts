import { Module } from '@nestjs/common';
import { ComprasController } from './controllers/compras.controller';
import { ComprasLogic } from './logic/compras.logic';
import { ComprasModel } from './models/compras.model';

@Module({
  controllers: [ComprasController],
  providers: [ComprasLogic, ComprasModel],
  exports: [ComprasLogic],
})
export class ComprasModule {}