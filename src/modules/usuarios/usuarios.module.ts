import { Module } from '@nestjs/common';
import { UsuariosController } from './controllers/usuarios.controller';
import { UsuariosLogic } from './logic/usuarios.logic';
import { UsuariosModel } from './models/usuarios.model';
import { UsuariosRolesModule } from '../usuarios-roles/usuarios-roles.module';

@Module({
  imports: [UsuariosRolesModule],
  controllers: [UsuariosController],
  providers: [UsuariosLogic, UsuariosModel],
  exports: [UsuariosLogic],
})
export class UsuariosModule {}
