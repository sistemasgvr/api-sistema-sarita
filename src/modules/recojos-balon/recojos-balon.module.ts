import { Module } from '@nestjs/common';
import { RecojosBalonController } from './controllers/recojos-balon.controller';
import { RecojosBalonLogic } from './logic/recojos-balon.logic';
import { RecojosBalonModel } from './models/recojos-balon.model';

@Module({
  controllers: [RecojosBalonController],
  providers: [RecojosBalonLogic, RecojosBalonModel],
})
export class RecojosBalonModule {}
