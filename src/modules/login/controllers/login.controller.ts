import { Body, Controller, Post, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { Public } from '../../../common/decorators/public.decorator';
import { LoginDto } from '../dto/login.dto';
import { LoginLogic } from '../logic/login.logic';

@ApiTags('Auth - Login')
@Controller('auth/login')
export class LoginController {
  constructor(private readonly loginLogic: LoginLogic) {}

  @Public()
  @Post()
  @ApiOperation({ summary: 'Iniciar sesión con correo y contraseña' })
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.loginLogic.login({
      ...dto,
      ip: dto.ip ?? req.ip,
      userAgent: dto.userAgent ?? req.headers['user-agent'],
    });
  }
}
