import { Module } from '@nestjs/common';
import { StorageModule } from '../storage/storage.module';
import { ProductosController } from './controllers/productos.controller';
import { ProductosLogic } from './logic/productos.logic';
import { ProductosModel } from './models/productos.model';
import { ProductoUbicacionPdfGenerator } from './services/producto-ubicacion-pdf.generator';

@Module({
  imports: [StorageModule],
  controllers: [ProductosController],
  providers: [ProductosLogic, ProductosModel, ProductoUbicacionPdfGenerator],
})
export class ProductosModule {}
