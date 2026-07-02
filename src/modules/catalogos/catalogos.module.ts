import { Module } from '@nestjs/common';
import { CatalogosController } from './controllers/catalogos.controller';
import { CatalogosLogic } from './logic/catalogos.logic';
import { CatalogosModel } from './models/catalogos.model';

@Module({
  controllers: [CatalogosController],
  providers: [CatalogosLogic, CatalogosModel],
})
export class CatalogosModule {}
