import { Module } from '@nestjs/common';
import { TrabajadoresController } from './controllers/trabajadores.controller';
import { TrabajadoresLogic } from './logic/trabajadores.logic';
import { TrabajadoresModel } from './models/trabajadores.model';
import { UsuariosModule } from '../usuarios/usuarios.module';
import { ChoferesModule } from '../choferes/choferes.module';

@Module({
  imports: [UsuariosModule, ChoferesModule],
  controllers: [TrabajadoresController],
  providers: [TrabajadoresLogic, TrabajadoresModel],
})
export class TrabajadoresModule {}
