import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import type { JwtSignOptions } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { JwtStrategy } from '../../common/strategies/jwt.strategy';
import { LoginController } from './controllers/login.controller';
import { LoginLogic } from './logic/login.logic';
import { LoginModel } from './models/login.model';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.getOrThrow<string>('jwt.secret'),
        signOptions: {
          expiresIn: (configService.get<string>('jwt.expiresIn') ??
            '24h') as JwtSignOptions['expiresIn'],
        },
      }),
    }),
  ],
  controllers: [LoginController],
  providers: [LoginModel, LoginLogic, JwtStrategy],
  exports: [JwtModule, PassportModule],
})
export class LoginModule {}
