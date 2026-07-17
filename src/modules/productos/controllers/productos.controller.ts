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
  CreateProductoDto,
  FiltroProductosDto,
  UpdateProductoDto,
} from '../dto/productos.dto';
import { ProductosLogic } from '../logic/productos.logic';

@ApiTags('Productos')
@Controller('productos')
export class ProductosController {
  constructor(private readonly productosLogic: ProductosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.PRODUCTOS_LISTAR)
  @ApiOperation({ summary: 'Listar productos' })
  listar(@Query() filtros: FiltroProductosDto) {
    return this.productosLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.PRODUCTOS_VER)
  @ApiOperation({ summary: 'Obtener producto por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.productosLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.PRODUCTOS_CREAR)
  @ApiOperation({ summary: 'Crear producto' })
  crear(@Body() dto: CreateProductoDto) {
    return this.productosLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar producto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateProductoDto,
  ) {
    return this.productosLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.PRODUCTOS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar producto (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.productosLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
