import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import databaseConfig from './config/database.config';
import jwtConfig from './config/jwt.config';
import { envValidationSchema } from './config/env.validation';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { DatabaseModule } from './database/database.module';
import { EjemploModule } from './modules/ejemplo/ejemplo.module';
import { LoginModule } from './modules/login/login.module';
import { PermisosModule } from './modules/permisos/permisos.module';
import { RolesModule } from './modules/roles/roles.module';
import { RolesPermisosModule } from './modules/roles-permisos/roles-permisos.module';
import { SesionesModule } from './modules/sesiones/sesiones.module';
import { UsuariosModule } from './modules/usuarios/usuarios.module';
import { UsuariosRolesModule } from './modules/usuarios-roles/usuarios-roles.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [databaseConfig, jwtConfig],
      validationSchema: envValidationSchema,
      validationOptions: {
        allowUnknown: true,
        abortEarly: false,
      },
    }),
    DatabaseModule,
    LoginModule,
    UsuariosModule,
    RolesModule,
    PermisosModule,
    UsuariosRolesModule,
    RolesPermisosModule,
    SesionesModule,
    EjemploModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
})
export class AppModule {}
