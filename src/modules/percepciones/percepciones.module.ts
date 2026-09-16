import { Module } from '@nestjs/common';
import { FacturacionApisperuModule } from '../../integrations/facturacion-apisperu/facturacion-apisperu.module';
import { FacturacionElectronicaModule } from '../facturacion-electronica/facturacion-electronica.module';
import { PercepcionesController } from './controllers/percepciones.controller';
import { PercepcionesLogic } from './logic/percepciones.logic';
import { PercepcionesModel } from './models/percepciones.model';
import { PercepcionMapper } from './mappers/percepcion.mapper';

@Module({
  imports: [FacturacionApisperuModule, FacturacionElectronicaModule],
  controllers: [PercepcionesController],
  providers: [PercepcionesLogic, PercepcionesModel, PercepcionMapper],
  exports: [PercepcionesLogic, PercepcionesModel],
})
export class PercepcionesModule {}
