import { Module } from '@nestjs/common';
import { StockProductoController } from './controllers/stock-producto.controller';
import { StockProductoLogic } from './logic/stock-producto.logic';
import { StockProductoModel } from './models/stock-producto.model';

@Module({
  controllers: [StockProductoController],
  providers: [StockProductoLogic, StockProductoModel],
})
export class StockProductoModule {}
