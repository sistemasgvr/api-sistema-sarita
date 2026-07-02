import { Module } from '@nestjs/common';
import { MovimientosInventarioController } from './controllers/movimientos-inventario.controller';
import { MovimientosInventarioLogic } from './logic/movimientos-inventario.logic';
import { MovimientosInventarioModel } from './models/movimientos-inventario.model';

@Module({
  controllers: [MovimientosInventarioController],
  providers: [MovimientosInventarioLogic, MovimientosInventarioModel],
})
export class MovimientosInventarioModule {}
