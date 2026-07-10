import { Module } from '@nestjs/common';
import { ComprobantesController } from './controllers/comprobantes.controller';
import { ComprobantesLogic } from './logic/comprobantes.logic';
import { ComprobantesModel } from './models/comprobantes.model';

@Module({
  controllers: [ComprobantesController],
  providers: [ComprobantesLogic, ComprobantesModel],
  exports: [ComprobantesLogic, ComprobantesModel],
})
export class ComprobantesModule {}
