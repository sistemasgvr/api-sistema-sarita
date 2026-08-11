import { Module } from '@nestjs/common';
import { RutasPueblosController } from './controllers/rutas-pueblos.controller';
import { RutasPueblosLogic } from './logic/rutas-pueblos.logic';
import { RutasPueblosModel } from './models/rutas-pueblos.model';

@Module({
  controllers: [RutasPueblosController],
  providers: [RutasPueblosLogic, RutasPueblosModel],
})
export class RutasPueblosModule {}
