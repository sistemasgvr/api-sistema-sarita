import {
  Body,
  Controller,
  Delete,
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
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import {
  CreateAlquileresDetalleDto,
  DevolverAlquileresDetalleDto,
  FiltroAlquileresDetalleDto,
  UpdateAlquileresDetalleDto,
} from '../dto/alquileres-detalle.dto';
import { AlquileresDetalleLogic } from '../logic/alquileres-detalle.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Balones - Alquileres Detalle')
@Controller('balones/alquileres-detalle')
export class AlquileresDetalleController {
  constructor(private readonly logic: AlquileresDetalleLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ALQUILERES_DETALLE_LISTAR)
  @ApiOperation({ summary: 'Listar' })
  listar(@Query() filtros: FiltroAlquileresDetalleDto) {
    return this.logic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ALQUILERES_DETALLE_VER)
  @ApiOperation({ summary: 'Obtener por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.ALQUILERES_DETALLE_CREAR)
  @ApiOperation({ summary: 'Crear' })
  crear(@Body() dto: CreateAlquileresDetalleDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.crear(dto);
  }

  @Post(':id/devolver')
  @Permisos(PermisoBanderas.ALQUILERES_DETALLE_EDITAR)
  @ApiOperation({ summary: 'Registrar devolución del cilindro' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  devolver(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: DevolverAlquileresDetalleDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.devolver(id, dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ALQUILERES_DETALLE_EDITAR)
  @ApiOperation({ summary: 'Actualizar' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAlquileresDetalleDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ALQUILERES_DETALLE_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
