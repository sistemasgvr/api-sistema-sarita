import { Module } from '@nestjs/common';
import { StorageModule } from '../storage/storage.module';
import { ActivosController } from './controllers/activos.controller';
import { ActivosLogic } from './logic/activos.logic';
import { ActivosModel } from './models/activos.model';

@Module({
  imports: [StorageModule],
  controllers: [ActivosController],
  providers: [ActivosLogic, ActivosModel],
})
export class ActivosModule {}
