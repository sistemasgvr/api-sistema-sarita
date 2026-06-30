import { Module } from '@nestjs/common';
import { ConfiguracionSunatController } from './controllers/configuracion-sunat.controller';
import { ConfiguracionSunatLogic } from './logic/configuracion-sunat.logic';
import { ConfiguracionSunatModel } from './models/configuracion-sunat.model';

@Module({
  controllers: [ConfiguracionSunatController],
  providers: [ConfiguracionSunatLogic, ConfiguracionSunatModel],
})
export class ConfiguracionSunatModule {}
