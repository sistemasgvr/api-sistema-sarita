import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { CreateSesionDto, ValidarSesionDto } from '../dto/create-sesion.dto';
import { FiltroSesionesDto } from '../dto/sesiones.dto';
import { SesionesLogic } from '../logic/sesiones.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Auth - Sesiones')
@Controller('auth/sesiones')
export class SesionesController {
  constructor(private readonly sesionesLogic: SesionesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.SESIONES_LISTAR)
  @ApiOperation({ summary: 'Listar sesiones' })
  listar(@Query() filtros: FiltroSesionesDto) {
    return this.sesionesLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.SESIONES_VER)
  @ApiOperation({ summary: 'Obtener sesión por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.sesionesLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.SESIONES_CREAR)
  @ApiOperation({ summary: 'Crear sesión' })
  crear(@Body() dto: CreateSesionDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.sesionesLogic.crear(dto);
  }

  @Post('validar')
  @ApiOperation({ summary: 'Validar token de sesión activa (requiere JWT)' })
  validar(@Body() dto: ValidarSesionDto) {
    return this.sesionesLogic.validar(dto);
  }

  @Patch(':id/cerrar')
  @Permisos(PermisoBanderas.SESIONES_CERRAR)
  @ApiOperation({ summary: 'Cerrar sesión' })
  cerrar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.sesionesLogic.cerrar(id, dto.idUsuarioAuditoria);
  }
}
