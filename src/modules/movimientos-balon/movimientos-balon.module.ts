import { Module } from '@nestjs/common';
import { MovimientosBalonController } from './controllers/movimientos-balon.controller';
import { MovimientosBalonLogic } from './logic/movimientos-balon.logic';
import { MovimientosBalonModel } from './models/movimientos-balon.model';

@Module({
  controllers: [MovimientosBalonController],
  providers: [MovimientosBalonLogic, MovimientosBalonModel],
})
export class MovimientosBalonModule {}
