import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConsultasController } from './controllers/consultas.controller';
import { ConsultasLogic } from './logic/consultas.logic';

@Module({
  imports: [HttpModule],
  controllers: [ConsultasController],
  providers: [ConsultasLogic],
  exports: [ConsultasLogic],
})
export class ConsultasModule {}
