import { Module } from '@nestjs/common';
import { PrestamosBalonController } from './controllers/prestamos-balon.controller';
import { PrestamosBalonLogic } from './logic/prestamos-balon.logic';
import { PrestamosBalonModel } from './models/prestamos-balon.model';

@Module({
  controllers: [PrestamosBalonController],
  providers: [PrestamosBalonLogic, PrestamosBalonModel],
})
export class PrestamosBalonModule {}
