import { Controller, Get, Post, Body, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { Public } from '../../../common/decorators/public.decorator';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { LoginDto } from '../dto/login.dto';
import { LoginLogic } from '../logic/login.logic';

@ApiTags('Auth - Login')
@Controller('auth')
export class LoginController {
  constructor(private readonly loginLogic: LoginLogic) {}

  @Public()
  @Post('login')
  @ApiOperation({ summary: 'Iniciar sesión con correo y contraseña' })
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.loginLogic.login({
      ...dto,
      ip: dto.ip ?? req.ip,
      userAgent: dto.userAgent ?? req.headers['user-agent'],
    });
  }

  @Post('logout')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Cerrar la sesión actual' })
  logout(@Req() req: Request & { user: AuthenticatedUser }) {
    return this.loginLogic.logout(req.user.sesion.id, req.user.id);
  }

  @Get('me')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Usuario autenticado y banderas de permiso' })
  me(@Req() req: Request & { user: AuthenticatedUser }) {
    const { id, correo, permisos, sesion } = req.user;
    return {
      id,
      correo,
      permisos,
      sesion,
    };
  }
}
