import { Module } from '@nestjs/common';
import { BajasClienteController } from './controllers/bajas-cliente.controller';
import { BajasClienteLogic } from './logic/bajas-cliente.logic';
import { BajasClienteModel } from './models/bajas-cliente.model';

@Module({
  controllers: [BajasClienteController],
  providers: [BajasClienteLogic, BajasClienteModel],
  exports: [BajasClienteLogic, BajasClienteModel],
})
export class BajasClienteModule {}
