import { Module } from '@nestjs/common';
import { DocumentosVencimientoController } from './controllers/documentos-vencimiento.controller';
import { DocumentosVencimientoLogic } from './logic/documentos-vencimiento.logic';
import { DocumentosVencimientoModel } from './models/documentos-vencimiento.model';

@Module({
  controllers: [DocumentosVencimientoController],
  providers: [DocumentosVencimientoLogic, DocumentosVencimientoModel],
  exports: [DocumentosVencimientoLogic, DocumentosVencimientoModel],
})
export class DocumentosVencimientoModule {}
