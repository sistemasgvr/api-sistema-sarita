import { Module } from '@nestjs/common';
import { BalonesController } from './controllers/balones.controller';
import { BalonesLogic } from './logic/balones.logic';
import { BalonesModel } from './models/balones.model';

@Module({
  controllers: [BalonesController],
  providers: [BalonesLogic, BalonesModel],
})
export class BalonesModule {}
