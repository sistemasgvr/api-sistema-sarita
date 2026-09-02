import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Query } from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  CreateInventarioMovimientoDto,
  FiltroInventarioMovimientosDto,
} from '../dto/inventario-movimientos.dto';
import { InventarioMovimientosLogic } from '../logic/inventario-movimientos.logic';

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
  @ApiOperation({ summary: 'Registrar movimiento de inventario (ajuste manual)' })
  crear(@Body() dto: CreateInventarioMovimientoDto) {
    return this.inventarioMovimientosLogic.crear(dto);
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
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.inventarioMovimientosLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
