import { Module } from '@nestjs/common';
import { TiposBalonController } from './controllers/tipos-balon.controller';
import { TiposBalonLogic } from './logic/tipos-balon.logic';
import { TiposBalonModel } from './models/tipos-balon.model';

@Module({
  controllers: [TiposBalonController],
  providers: [TiposBalonLogic, TiposBalonModel],
})
export class TiposBalonModule {}
