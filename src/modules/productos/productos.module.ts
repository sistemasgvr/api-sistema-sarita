import { Module } from '@nestjs/common';
import { ProductoImagenesModule } from '../producto-imagenes/producto-imagenes.module';
import { ProductosController } from './controllers/productos.controller';
import { ProductosLogic } from './logic/productos.logic';
import { ProductosModel } from './models/productos.model';

@Module({
  imports: [ProductoImagenesModule],
  controllers: [ProductosController],
  providers: [ProductosLogic, ProductosModel],
})
export class ProductosModule {}
