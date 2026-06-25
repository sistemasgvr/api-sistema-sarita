import { Module } from '@nestjs/common';
import { RolesController } from './controllers/roles.controller';
import { RolesLogic } from './logic/roles.logic';
import { RolesModel } from './models/roles.model';

@Module({
  controllers: [RolesController],
  providers: [RolesLogic, RolesModel],
})
export class RolesModule {}
