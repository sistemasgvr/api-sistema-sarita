import { Module } from '@nestjs/common';
import { FacturacionApisperuModule } from '../../integrations/facturacion-apisperu/facturacion-apisperu.module';
import { GuiasRemisionController } from './controllers/guias-remision.controller';
import { GuiasRemisionLogic } from './logic/guias-remision.logic';
import { GuiaRemisionDespatchMapper } from './mappers/guia-remision-despatch.mapper';
import { GuiasRemisionModel } from './models/guias-remision.model';
import { GuiaRemisionPdfGenerator } from './services/guia-remision-pdf.generator';

@Module({
  imports: [FacturacionApisperuModule],
  controllers: [GuiasRemisionController],
  providers: [
    GuiasRemisionLogic,
    GuiasRemisionModel,
    GuiaRemisionDespatchMapper,
    GuiaRemisionPdfGenerator,
  ],
  exports: [GuiasRemisionLogic, GuiasRemisionModel],
})
export class GuiasRemisionModule {}
