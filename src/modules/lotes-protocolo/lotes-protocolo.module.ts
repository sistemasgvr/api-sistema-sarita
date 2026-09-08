import { Module } from '@nestjs/common';
import { LotesProtocoloController } from './controllers/lotes-protocolo.controller';
import { LotesProtocoloLogic } from './logic/lotes-protocolo.logic';
import { LotesProtocoloModel } from './models/lotes-protocolo.model';

@Module({
  controllers: [LotesProtocoloController],
  providers: [LotesProtocoloLogic, LotesProtocoloModel],
})
export class LotesProtocoloModule {}
