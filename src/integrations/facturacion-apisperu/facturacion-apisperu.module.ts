import { HttpModule } from '@nestjs/axios';
import { Global, Module } from '@nestjs/common';
import { FacturacionCredentialsService } from '../facturacion-electronica/facturacion-credentials.service';
import { FacturacionApisperuClient } from './facturacion-apisperu.client';

@Global()
@Module({
  imports: [
    HttpModule.register({
      maxRedirects: 3,
    }),
  ],
  providers: [FacturacionCredentialsService, FacturacionApisperuClient],
  exports: [FacturacionCredentialsService, FacturacionApisperuClient],
})
export class FacturacionApisperuModule {}