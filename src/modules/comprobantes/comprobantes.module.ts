import { Module } from '@nestjs/common';
import { ClientesModule } from '../clientes/clientes.module';
import { ComprobantesController } from './controllers/comprobantes.controller';
import { ComprobantesLogic } from './logic/comprobantes.logic';
import { ComprobanteInvoiceMapper } from './mappers/comprobante-invoice.mapper';
import { ComprobantesModel } from './models/comprobantes.model';

@Module({
  imports: [ClientesModule],
  controllers: [ComprobantesController],
  providers: [ComprobantesLogic, ComprobantesModel, ComprobanteInvoiceMapper],
  exports: [ComprobantesLogic, ComprobantesModel, ComprobanteInvoiceMapper],
})
export class ComprobantesModule {}
