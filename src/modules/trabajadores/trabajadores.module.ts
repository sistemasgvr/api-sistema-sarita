import { Module } from '@nestjs/common';
import { TrabajadoresController } from './controllers/trabajadores.controller';
import { TrabajadoresLogic } from './logic/trabajadores.logic';
import { TrabajadoresModel } from './models/trabajadores.model';
import { UsuariosModule } from '../usuarios/usuarios.module';

@Module({
  imports: [UsuariosModule],
  controllers: [TrabajadoresController],
  providers: [TrabajadoresLogic, TrabajadoresModel],
})
export class TrabajadoresModule {}
