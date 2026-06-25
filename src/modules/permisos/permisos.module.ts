import { Module } from '@nestjs/common';
import { PermisosController } from './controllers/permisos.controller';
import { PermisosLogic } from './logic/permisos.logic';
import { PermisosModel } from './models/permisos.model';

@Module({
  controllers: [PermisosController],
  providers: [PermisosLogic, PermisosModel],
})
export class PermisosModule {}
