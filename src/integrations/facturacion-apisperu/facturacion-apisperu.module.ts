import { HttpModule } from '@nestjs/axios';
import { SunatValidezClient } from '../facturacion-electronica/sunat-validez.client';
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
  providers: [FacturacionCredentialsService, FacturacionApisperuClient, SunatValidezClient],
  exports: [FacturacionCredentialsService, FacturacionApisperuClient, SunatValidezClient],
})
export class FacturacionApisperuModule {}