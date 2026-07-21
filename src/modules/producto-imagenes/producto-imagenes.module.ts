import { Module } from '@nestjs/common';
import { StorageModule } from '../storage/storage.module';
import { ProductoImagenesController } from './controllers/producto-imagenes.controller';
import { ProductoImagenesLogic } from './logic/producto-imagenes.logic';
import { ProductoImagenesModel } from './models/producto-imagenes.model';

@Module({
  imports: [StorageModule],
  controllers: [ProductoImagenesController],
  providers: [ProductoImagenesLogic, ProductoImagenesModel],
  exports: [ProductoImagenesLogic],
})
export class ProductoImagenesModule {}
