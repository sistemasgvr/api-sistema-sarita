import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { DashboardController } from './controllers/dashboard.controller';
import { DashboardLogic } from './logic/dashboard.logic';
import { DashboardModel } from './models/dashboard.model';

@Module({
  imports: [DatabaseModule],
  controllers: [DashboardController],
  providers: [DashboardLogic, DashboardModel],
})
export class DashboardModule {}