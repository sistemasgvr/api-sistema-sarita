import { Module } from '@nestjs/common';
import { CategoriasProductoController } from './controllers/categorias-producto.controller';
import { CategoriasProductoLogic } from './logic/categorias-producto.logic';
import { CategoriasProductoModel } from './models/categorias-producto.model';

@Module({
  controllers: [CategoriasProductoController],
  providers: [CategoriasProductoLogic, CategoriasProductoModel],
})
export class CategoriasProductoModule {}
