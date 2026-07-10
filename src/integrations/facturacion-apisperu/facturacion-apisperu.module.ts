import { HttpModule } from '@nestjs/axios';
import { Global, Module } from '@nestjs/common';
import { FacturacionApisperuClient } from './facturacion-apisperu.client';

@Global()
@Module({
  imports: [
    HttpModule.register({
      maxRedirects: 3,
    }),
  ],
  providers: [FacturacionApisperuClient],
  exports: [FacturacionApisperuClient],
})
export class FacturacionApisperuModule {}
