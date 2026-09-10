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
  CreateMantenimientosBalonDto,
  FinalizarMantenimientosBalonDto,
  FiltroMantenimientosBalonDto,
  UpdateMantenimientosBalonDto,
} from '../dto/mantenimientos-balon.dto';
import { MantenimientosBalonLogic } from '../logic/mantenimientos-balon.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Balones - Mantenimientos')
@Controller('balones/mantenimientos')
export class MantenimientosBalonController {
  constructor(private readonly logic: MantenimientosBalonLogic) {}

  @Get()
  @Permisos(PermisoBanderas.MANTENIMIENTOS_BALON_LISTAR)
  @ApiOperation({ summary: 'Listar' })
  listar(@Query() filtros: FiltroMantenimientosBalonDto) {
    return this.logic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.MANTENIMIENTOS_BALON_VER)
  @ApiOperation({ summary: 'Obtener por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.MANTENIMIENTOS_BALON_CREAR)
  @ApiOperation({ summary: 'Crear' })
  crear(@Body() dto: CreateMantenimientosBalonDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.crear(dto);
  }

  @Post(':id/finalizar')
  @Permisos(PermisoBanderas.MANTENIMIENTOS_BALON_EDITAR)
  @ApiOperation({
    summary: 'Finalizar mantenimiento (reingreso del cilindro a almacén)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  finalizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: FinalizarMantenimientosBalonDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.finalizar(id, dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.MANTENIMIENTOS_BALON_EDITAR)
  @ApiOperation({ summary: 'Actualizar' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateMantenimientosBalonDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.MANTENIMIENTOS_BALON_ELIMINAR)
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
