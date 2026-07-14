import { Module } from '@nestjs/common';
import { ProductosController } from './controllers/productos.controller';
import { ProductosLogic } from './logic/productos.logic';
import { ProductosModel } from './models/productos.model';

@Module({
  controllers: [ProductosController],
  providers: [ProductosLogic, ProductosModel],
})
export class ProductosModule {}
