import { Module } from '@nestjs/common';
import { ChoferesController } from './controllers/choferes.controller';
import { ChoferesLogic } from './logic/choferes.logic';
import { ChoferesModel } from './models/choferes.model';

@Module({
  controllers: [ChoferesController],
  providers: [ChoferesLogic, ChoferesModel],
})
export class ChoferesModule {}
