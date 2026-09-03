import { Module } from '@nestjs/common';
import { FacturacionApisperuModule } from '../../integrations/facturacion-apisperu/facturacion-apisperu.module';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';
import { DocumentosSalidaController } from './controllers/documentos-salida.controller';
import { DocumentosSalidaLogic } from './logic/documentos-salida.logic';
import { DocSalidaDespatchMapper } from './mappers/doc-salida-despatch.mapper';
import { DocumentosSalidaModel } from './models/documentos-salida.model';
import { DocSalidaPdfGenerator } from './services/doc-salida-pdf.generator';

@Module({
  imports: [FacturacionApisperuModule, NotificacionesModule],
  controllers: [DocumentosSalidaController],
  providers: [DocumentosSalidaLogic, DocumentosSalidaModel, DocSalidaDespatchMapper, DocSalidaPdfGenerator],
  exports: [DocumentosSalidaLogic, DocumentosSalidaModel],
})
export class DocumentosSalidaModule {}
