import { Module } from '@nestjs/common';
import { ProductosController } from './controllers/productos.controller';
import { ProductosLogic } from './logic/productos.logic';
import { ProductosModel } from './models/productos.model';
import { ProductoUbicacionPdfGenerator } from './services/producto-ubicacion-pdf.generator';

@Module({
  controllers: [ProductosController],
  providers: [ProductosLogic, ProductosModel, ProductoUbicacionPdfGenerator],
})
export class ProductosModule {}
