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
  UseGuards,
} from '@nestjs/common';
import {
  ApiHeader,
  ApiNotFoundResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { Request } from 'express';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { Public } from '../../../common/decorators/public.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { NotificacionesJobsTokenGuard } from '../../../common/guards/notificaciones-jobs-token.guard';
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
  @Public()
  @UseGuards(NotificacionesJobsTokenGuard)
  @ApiHeader({
    name: 'X-Notificaciones-Jobs-Token',
    description:
      'Token de entorno NOTIFICACIONES_JOBS_TOKEN (también acepta Authorization: Bearer <token>)',
    required: true,
  })
  @ApiOperation({
    summary: 'Ejecutar detección/notificación de alquileres vencidos (manual)',
  })
  ejecutarAlquileresVencidos() {
    return this.logic.detectarYNotificarAlquileresVencidos();
  }

  @Post('jobs/alquileres-por-vencer')
  @Public()
  @UseGuards(NotificacionesJobsTokenGuard)
  @ApiHeader({
    name: 'X-Notificaciones-Jobs-Token',
    description:
      'Token de entorno NOTIFICACIONES_JOBS_TOKEN (también acepta Authorization: Bearer <token>)',
    required: true,
  })
  @ApiOperation({
    summary: 'Detectar alquileres por vencer en 3–7 días (manual)',
  })
  ejecutarAlquileresPorVencer() {
    return this.logic.detectarYNotificarAlquileresPorVencer();
  }

  @Post('jobs/prestamos-vencidos')
  @Public()
  @UseGuards(NotificacionesJobsTokenGuard)
  @ApiHeader({
    name: 'X-Notificaciones-Jobs-Token',
    description:
      'Token de entorno NOTIFICACIONES_JOBS_TOKEN (también acepta Authorization: Bearer <token>)',
    required: true,
  })
  @ApiOperation({ summary: 'Detectar préstamos vencidos (manual)' })
  ejecutarPrestamosVencidos() {
    return this.logic.detectarYNotificarPrestamosVencidos();
  }

  @Post('jobs/prestamos-por-vencer')
  @Public()
  @UseGuards(NotificacionesJobsTokenGuard)
  @ApiHeader({
    name: 'X-Notificaciones-Jobs-Token',
    description:
      'Token de entorno NOTIFICACIONES_JOBS_TOKEN (también acepta Authorization: Bearer <token>)',
    required: true,
  })
  @ApiOperation({
    summary: 'Detectar préstamos por vencer en 3–7 días (manual)',
  })
  ejecutarPrestamosPorVencer() {
    return this.logic.detectarYNotificarPrestamosPorVencer();
  }

  @Post('jobs/stock-bajo')
  @Public()
  @UseGuards(NotificacionesJobsTokenGuard)
  @ApiHeader({
    name: 'X-Notificaciones-Jobs-Token',
    description:
      'Token de entorno NOTIFICACIONES_JOBS_TOKEN (también acepta Authorization: Bearer <token>)',
    required: true,
  })
  @ApiOperation({ summary: 'Detectar stock bajo / cero (manual)' })
  ejecutarStockBajo() {
    return this.logic.detectarYNotificarStockBajo();
  }
}
