import { Module } from '@nestjs/common';
import { MovimientosRecargaController } from './controllers/movimientos-recarga.controller';
import { MovimientosRecargaLogic } from './logic/movimientos-recarga.logic';
import { MovimientosRecargaModel } from './models/movimientos-recarga.model';

@Module({
  controllers: [MovimientosRecargaController],
  providers: [MovimientosRecargaLogic, MovimientosRecargaModel],
})
export class MovimientosRecargaModule {}
