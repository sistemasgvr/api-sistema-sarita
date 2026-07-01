import { Module } from '@nestjs/common';
import { ClientesController } from './controllers/clientes.controller';
import { ClientesLogic } from './logic/clientes.logic';
import { ClientesModel } from './models/clientes.model';

@Module({
  controllers: [ClientesController],
  providers: [ClientesLogic, ClientesModel],
  exports: [ClientesLogic, ClientesModel],
})
export class ClientesModule {}
