import { Module } from '@nestjs/common';
import { SucursalesController } from './controllers/sucursales.controller';
import { SucursalesLogic } from './logic/sucursales.logic';
import { SucursalesModel } from './models/sucursales.model';

@Module({
  controllers: [SucursalesController],
  providers: [SucursalesLogic, SucursalesModel],
})
export class SucursalesModule {}
