import { Module } from '@nestjs/common';
import { SubCategoriasProductoController } from './controllers/sub-categorias-producto.controller';
import { SubCategoriasProductoLogic } from './logic/sub-categorias-producto.logic';
import { SubCategoriasProductoModel } from './models/sub-categorias-producto.model';

@Module({
  controllers: [SubCategoriasProductoController],
  providers: [SubCategoriasProductoLogic, SubCategoriasProductoModel],
})
export class SubCategoriasProductoModule {}
