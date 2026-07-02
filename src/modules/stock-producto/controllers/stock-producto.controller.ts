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
  CreateStockDto,
  FiltroStockDto,
  UpdateStockDto,
} from '../dto/stock-producto.dto';
import { StockProductoLogic } from '../logic/stock-producto.logic';

@ApiTags('Productos - Stock')
@Controller('productos/stock')
export class StockProductoController {
  constructor(private readonly stockProductoLogic: StockProductoLogic) {}

  @Get()
  @Permisos(PermisoBanderas.STOCK_LISTAR)
  @ApiOperation({ summary: 'Listar stock por almacén y producto' })
  listar(@Query() filtros: FiltroStockDto) {
    return this.stockProductoLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.STOCK_VER)
  @ApiOperation({ summary: 'Obtener registro de stock por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.stockProductoLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.STOCK_CREAR)
  @ApiOperation({ summary: 'Registrar stock inicial' })
  crear(@Body() dto: CreateStockDto) {
    return this.stockProductoLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.STOCK_EDITAR)
  @ApiOperation({ summary: 'Ajustar stock o stock mínimo' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateStockDto,
  ) {
    return this.stockProductoLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.STOCK_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar registro de stock (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.stockProductoLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
