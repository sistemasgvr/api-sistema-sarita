import { Module } from '@nestjs/common';
import { FacturacionElectronicaController } from './controllers/facturacion-electronica.controller';
import { FacturacionElectronicaLogic } from './logic/facturacion-electronica.logic';

@Module({
  controllers: [FacturacionElectronicaController],
  providers: [FacturacionElectronicaLogic],
  exports: [FacturacionElectronicaLogic],
})
export class FacturacionElectronicaModule {}
