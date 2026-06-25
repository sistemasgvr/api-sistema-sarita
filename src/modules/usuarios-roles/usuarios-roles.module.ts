import { Module } from '@nestjs/common';
import { UsuariosRolesController } from './controllers/usuarios-roles.controller';
import { UsuariosRolesLogic } from './logic/usuarios-roles.logic';
import { UsuariosRolesModel } from './models/usuarios-roles.model';

@Module({
  controllers: [UsuariosRolesController],
  providers: [UsuariosRolesLogic, UsuariosRolesModel],
})
export class UsuariosRolesModule {}
