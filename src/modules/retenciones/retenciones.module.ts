import { Module } from '@nestjs/common';
import { FacturacionApisperuModule } from '../../integrations/facturacion-apisperu/facturacion-apisperu.module';
import { FacturacionElectronicaModule } from '../facturacion-electronica/facturacion-electronica.module';
import { RetencionesController } from './controllers/retenciones.controller';
import { RetencionesLogic } from './logic/retenciones.logic';
import { RetencionesModel } from './models/retenciones.model';
import { RetencionMapper } from './mappers/retencion.mapper';

@Module({
  imports: [FacturacionApisperuModule, FacturacionElectronicaModule],
  controllers: [RetencionesController],
  providers: [RetencionesLogic, RetencionesModel, RetencionMapper],
  exports: [RetencionesLogic, RetencionesModel],
})
export class RetencionesModule {}
