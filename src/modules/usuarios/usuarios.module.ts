import { Module } from '@nestjs/common';
import { UsuariosController } from './controllers/usuarios.controller';
import { UsuariosLogic } from './logic/usuarios.logic';
import { UsuariosModel } from './models/usuarios.model';

@Module({
  controllers: [UsuariosController],
  providers: [UsuariosLogic, UsuariosModel],
})
export class UsuariosModule {}
