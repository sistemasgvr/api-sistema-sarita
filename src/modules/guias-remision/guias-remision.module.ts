import { Module } from '@nestjs/common';
import { GuiasRemisionController } from './controllers/guias-remision.controller';
import { GuiasRemisionLogic } from './logic/guias-remision.logic';
import { GuiaRemisionDespatchMapper } from './mappers/guia-remision-despatch.mapper';
import { GuiasRemisionModel } from './models/guias-remision.model';
import { GuiaRemisionPdfGenerator } from './services/guia-remision-pdf.generator';

@Module({
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
