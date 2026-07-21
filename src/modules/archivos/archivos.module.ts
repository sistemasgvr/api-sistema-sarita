import { Module } from '@nestjs/common';
import { ArchivosController } from './controllers/archivos.controller';
import { ArchivosLogic } from './logic/archivos.logic';
import { ArchivosModel } from './models/archivos.model';

@Module({
  controllers: [ArchivosController],
  providers: [ArchivosLogic, ArchivosModel],
  exports: [ArchivosLogic, ArchivosModel],
})
export class ArchivosModule {}
