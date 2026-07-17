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
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  CreateMovimientoInventarioDto,
  FiltroMovimientosInventarioDto,
  UpdateMovimientoInventarioDto,
} from '../dto/movimientos-inventario.dto';
import { MovimientosInventarioLogic } from '../logic/movimientos-inventario.logic';

@ApiTags('Productos - Movimientos (Kardex)')
@Controller('productos/movimientos')
export class MovimientosInventarioController {
  constructor(private readonly movimientosInventarioLogic: MovimientosInventarioLogic) {}

  @Get()
  @Permisos(PermisoBanderas.MOVIMIENTOS_LISTAR)
  @ApiOperation({ summary: 'Listar movimientos de inventario' })
  listar(@Query() filtros: FiltroMovimientosInventarioDto) {
    return this.movimientosInventarioLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.MOVIMIENTOS_VER)
  @ApiOperation({ summary: 'Obtener movimiento por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.movimientosInventarioLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.MOVIMIENTOS_CREAR)
  @ApiOperation({ summary: 'Registrar movimiento de inventario' })
  crear(@Body() dto: CreateMovimientoInventarioDto) {
    return this.movimientosInventarioLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.MOVIMIENTOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar glosa o referencia del movimiento' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateMovimientoInventarioDto,
  ) {
    return this.movimientosInventarioLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.MOVIMIENTOS_ELIMINAR)
  @ApiOperation({ summary: 'Anular movimiento de inventario' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.movimientosInventarioLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
