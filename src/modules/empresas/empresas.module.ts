import { Module } from '@nestjs/common';
import { EmpresasController } from './controllers/empresas.controller';
import { EmpresasLogic } from './logic/empresas.logic';
import { EmpresasModel } from './models/empresas.model';

@Module({
  controllers: [EmpresasController],
  providers: [EmpresasLogic, EmpresasModel],
})
export class EmpresasModule {}
