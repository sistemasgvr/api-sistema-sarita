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
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import {
  CrearNotificacionDto,
  FiltroNotificacionesDto,
} from '../dto/notificaciones.dto';
import { NotificacionesLogic } from '../logic/notificaciones.logic';

@ApiTags('Notificaciones')
@Controller('notificaciones')
export class NotificacionesController {
  constructor(private readonly logic: NotificacionesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.NOTIFICACIONES_LISTAR)
  @ApiOperation({ summary: 'Listar notificaciones del usuario autenticado' })
  listar(
    @Req() req: Request & { user: AuthenticatedUser },
    @Query() filtros: FiltroNotificacionesDto,
  ) {
    return this.logic.listar(req.user.id, filtros);
  }

  @Get('no-leidas/contador')
  @Permisos(PermisoBanderas.NOTIFICACIONES_LISTAR)
  @ApiOperation({ summary: 'Contar notificaciones no leídas' })
  contarNoLeidas(@Req() req: Request & { user: AuthenticatedUser }) {
    return this.logic.contarNoLeidas(req.user.id);
  }

  @Patch('leidas/todas')
  @Permisos(PermisoBanderas.NOTIFICACIONES_MARCAR_LEIDA)
  @ApiOperation({ summary: 'Marcar todas las notificaciones como leídas' })
  marcarTodas(@Req() req: Request & { user: AuthenticatedUser }) {
    return this.logic.marcarTodasLeidas(req.user.id);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.NOTIFICACIONES_VER)
  @ApiOperation({ summary: 'Obtener notificación por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(
    @Req() req: Request & { user: AuthenticatedUser },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.logic.obtenerPorId(id, req.user.id);
  }

  @Patch(':id/leida')
  @Permisos(PermisoBanderas.NOTIFICACIONES_MARCAR_LEIDA)
  @ApiOperation({ summary: 'Marcar notificación como leída' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  marcarLeida(
    @Req() req: Request & { user: AuthenticatedUser },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.logic.marcarLeida(id, req.user.id);
  }

  @Post()
  @Permisos(PermisoBanderas.NOTIFICACIONES_CREAR)
  @ApiOperation({
    summary:
      'Crear notificación(es) genéricas (usuario, lista, roles y/o permiso)',
  })
  crear(
    @Req() req: Request & { user: AuthenticatedUser },
    @Body() dto: CrearNotificacionDto,
  ) {
    return this.logic.enviar(dto, req.user.id);
  }

  @Post('jobs/alquileres-vencidos')
  @Permisos(PermisoBanderas.NOTIFICACIONES_EJECUTAR_JOBS)
  @ApiOperation({
    summary: 'Ejecutar detección/notificación de alquileres vencidos (manual)',
  })
  ejecutarAlquileresVencidos(
    @Req() req: Request & { user: AuthenticatedUser },
  ) {
    return this.logic.detectarYNotificarAlquileresVencidos(req.user.id);
  }
}
