import { Module } from '@nestjs/common';
import { CuentasBancariasController } from './controllers/cuentas-bancarias.controller';
import { CuentasBancariasLogic } from './logic/cuentas-bancarias.logic';
import { CuentasBancariasModel } from './models/cuentas-bancarias.model';

@Module({
  controllers: [CuentasBancariasController],
  providers: [CuentasBancariasLogic, CuentasBancariasModel],
  exports: [CuentasBancariasLogic, CuentasBancariasModel],
})
export class CuentasBancariasModule {}
