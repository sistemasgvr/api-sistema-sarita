import { Module } from '@nestjs/common';
import { ImageCompressionService } from '../../common/services/image-compression.service';
import { ArchivosModule } from '../archivos/archivos.module';
import { StorageController } from './controllers/storage.controller';
import { StorageLogic } from './logic/storage.logic';

@Module({
  imports: [ArchivosModule],
  controllers: [StorageController],
  providers: [StorageLogic, ImageCompressionService],
  exports: [StorageLogic],
})
export class StorageModule {}
