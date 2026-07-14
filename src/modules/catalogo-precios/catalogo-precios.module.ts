import { Module } from '@nestjs/common';
import { CatalogoPreciosController } from './controllers/catalogo-precios.controller';
import { CatalogoPreciosLogic } from './logic/catalogo-precios.logic';
import { CatalogoPreciosModel } from './models/catalogo-precios.model';

@Module({
  controllers: [CatalogoPreciosController],
  providers: [CatalogoPreciosLogic, CatalogoPreciosModel],
})
export class CatalogoPreciosModule {}
