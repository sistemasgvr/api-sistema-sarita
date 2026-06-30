import { Module } from '@nestjs/common';
import { CondicionesPagoController } from './controllers/condiciones-pago.controller';
import { CondicionesPagoLogic } from './logic/condiciones-pago.logic';
import { CondicionesPagoModel } from './models/condiciones-pago.model';

@Module({
  controllers: [CondicionesPagoController],
  providers: [CondicionesPagoLogic, CondicionesPagoModel],
})
export class CondicionesPagoModule {}
