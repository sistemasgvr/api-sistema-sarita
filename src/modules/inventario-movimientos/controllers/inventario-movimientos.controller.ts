import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
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
  CreateInventarioMovimientoDto,
  CreateTrasladoLoteInventarioDto,
  FiltroInventarioMovimientosDto,
} from '../dto/inventario-movimientos.dto';
import { InventarioMovimientosLogic } from '../logic/inventario-movimientos.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Inventario - Movimientos unificados')
@Controller('inventario/movimientos')
export class InventarioMovimientosController {
  constructor(private readonly inventarioMovimientosLogic: InventarioMovimientosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.INVENTARIO_MOVIMIENTOS_LISTAR)
  @ApiOperation({ summary: 'Listar movimientos de inventario (producto y balón unificados)' })
  listar(@Query() filtros: FiltroInventarioMovimientosDto) {
    return this.inventarioMovimientosLogic.listar(filtros);
  }

  @Post()
  @Permisos(PermisoBanderas.INVENTARIO_MOVIMIENTOS_CREAR)
  @ApiOperation({ summary: 'Registrar movimiento de inventario (ajuste / traslado / manual)' })
  crear(@Body() dto: CreateInventarioMovimientoDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.inventarioMovimientosLogic.crear(dto);
  }

  @Post('traslado-lote')
  @Permisos(PermisoBanderas.INVENTARIO_MOVIMIENTOS_CREAR)
  @ApiOperation({ summary: 'Registrar traslado multi-línea (atómico) vía inv_movimiento' })
  crearTrasladoLote(
    @Body() dto: CreateTrasladoLoteInventarioDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.inventarioMovimientosLogic.crearTrasladoLote(dto);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.INVENTARIO_MOVIMIENTOS_VER)
  @ApiOperation({ summary: 'Obtener movimiento por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.inventarioMovimientosLogic.obtenerPorId(id);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.INVENTARIO_MOVIMIENTOS_ELIMINAR)
  @ApiOperation({ summary: 'Anular movimiento de inventario sin documento origen' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.inventarioMovimientosLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
