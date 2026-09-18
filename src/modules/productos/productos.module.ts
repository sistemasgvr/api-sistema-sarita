import { Module } from '@nestjs/common';
import { StorageModule } from '../storage/storage.module';
import { ProductosController } from './controllers/productos.controller';
import { ProductosLogic } from './logic/productos.logic';
import { ProductosModel } from './models/productos.model';
import { ProductoEtiquetaPdfGenerator } from './services/producto-etiqueta-pdf.generator';
import { ProductoUbicacionPdfGenerator } from './services/producto-ubicacion-pdf.generator';

@Module({
  imports: [StorageModule],
  controllers: [ProductosController],
  providers: [ProductosLogic, ProductosModel, ProductoUbicacionPdfGenerator, ProductoEtiquetaPdfGenerator],
})
export class ProductosModule {}
