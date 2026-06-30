import { Module } from '@nestjs/common';
import { AlmacenesController } from './controllers/almacenes.controller';
import { AlmacenesLogic } from './logic/almacenes.logic';
import { AlmacenesModel } from './models/almacenes.model';

@Module({
  controllers: [AlmacenesController],
  providers: [AlmacenesLogic, AlmacenesModel],
})
export class AlmacenesModule {}
