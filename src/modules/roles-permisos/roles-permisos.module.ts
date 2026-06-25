import { Module } from '@nestjs/common';
import { RolesPermisosController } from './controllers/roles-permisos.controller';
import { RolesPermisosLogic } from './logic/roles-permisos.logic';
import { RolesPermisosModel } from './models/roles-permisos.model';

@Module({
  controllers: [RolesPermisosController],
  providers: [RolesPermisosLogic, RolesPermisosModel],
})
export class RolesPermisosModule {}
