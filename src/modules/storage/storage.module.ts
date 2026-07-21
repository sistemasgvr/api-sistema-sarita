import { Module } from '@nestjs/common';
import { ArchivosModule } from '../archivos/archivos.module';
import { StorageController } from './controllers/storage.controller';
import { StorageLogic } from './logic/storage.logic';

@Module({
  imports: [ArchivosModule],
  controllers: [StorageController],
  providers: [StorageLogic],
  exports: [StorageLogic],
})
export class StorageModule {}
