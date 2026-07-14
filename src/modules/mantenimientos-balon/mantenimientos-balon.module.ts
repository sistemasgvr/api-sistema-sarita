import { Module } from '@nestjs/common';
import { MantenimientosBalonController } from './controllers/mantenimientos-balon.controller';
import { MantenimientosBalonLogic } from './logic/mantenimientos-balon.logic';
import { MantenimientosBalonModel } from './models/mantenimientos-balon.model';

@Module({
  controllers: [MantenimientosBalonController],
  providers: [MantenimientosBalonLogic, MantenimientosBalonModel],
})
export class MantenimientosBalonModule {}
