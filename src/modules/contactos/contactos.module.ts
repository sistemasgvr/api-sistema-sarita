import { Module } from '@nestjs/common';
import { ContactosController } from './controllers/contactos.controller';
import { ContactosLogic } from './logic/contactos.logic';
import { ContactosModel } from './models/contactos.model';

@Module({
  controllers: [ContactosController],
  providers: [ContactosLogic, ContactosModel],
  exports: [ContactosLogic, ContactosModel],
})
export class ContactosModule {}
