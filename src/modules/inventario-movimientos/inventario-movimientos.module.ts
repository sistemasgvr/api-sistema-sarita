import { Module } from '@nestjs/common';
import { InventarioMovimientosController } from './controllers/inventario-movimientos.controller';
import { InventarioMovimientosLogic } from './logic/inventario-movimientos.logic';
import { InventarioMovimientosModel } from './models/inventario-movimientos.model';

@Module({
  controllers: [InventarioMovimientosController],
  providers: [InventarioMovimientosLogic, InventarioMovimientosModel],
})
export class InventarioMovimientosModule {}
