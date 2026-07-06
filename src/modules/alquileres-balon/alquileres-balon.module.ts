import { Module } from '@nestjs/common';
import { AlquileresBalonController } from './controllers/alquileres-balon.controller';
import { AlquileresBalonLogic } from './logic/alquileres-balon.logic';
import { AlquileresBalonModel } from './models/alquileres-balon.model';

@Module({
  controllers: [AlquileresBalonController],
  providers: [AlquileresBalonLogic, AlquileresBalonModel],
})
export class AlquileresBalonModule {}
