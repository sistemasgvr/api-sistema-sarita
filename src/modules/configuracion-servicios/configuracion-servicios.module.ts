import { Module } from '@nestjs/common';
import { ConfiguracionServiciosController } from './controllers/configuracion-servicios.controller';
import { ConfiguracionServiciosLogic } from './logic/configuracion-servicios.logic';
import { ConfiguracionServiciosModel } from './models/configuracion-servicios.model';

@Module({
  controllers: [ConfiguracionServiciosController],
  providers: [ConfiguracionServiciosLogic, ConfiguracionServiciosModel],
})
export class ConfiguracionServiciosModule {}
