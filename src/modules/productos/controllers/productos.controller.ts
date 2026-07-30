import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  StreamableFile,
} from '@nestjs/common';
import {
  ApiNotFoundResponse,
  ApiOperation,
  ApiProduces,
  ApiTags,
} from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  CreateProductoDto,
  FiltroProductosDto,
  GenerarCodigoUbicacionDto,
  ImprimirUbicacionesProductoDto,
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

  @Post('codigo-ubicacion/generar')
  @Permisos(PermisoBanderas.PRODUCTOS_LISTAR)
  @ApiOperation({
    summary:
      'Generar código de ubicación profesional (iniciales nombre/marca + correlativo). Si envía idProducto, lo asigna en BD.',
  })
  generarCodigoUbicacion(@Body() dto: GenerarCodigoUbicacionDto) {
    return this.productosLogic.generarCodigoUbicacion(dto);
  }

  @Post('ubicaciones/pdf')
  @Permisos(PermisoBanderas.PRODUCTOS_VER)
  @ApiOperation({
    summary: 'Generar PDF de tarjetas de ubicación para productos seleccionados',
  })
  @ApiProduces('application/pdf')
  @Header('Content-Type', 'application/pdf')
  async generarPdfUbicaciones(@Body() dto: ImprimirUbicacionesProductoDto) {
    const { buffer, filename } =
      await this.productosLogic.generarPdfUbicaciones(dto);

    return new StreamableFile(buffer, {
      type: 'application/pdf',
      disposition: `inline; filename="${filename}"`,
    });
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

  @Patch(':id/restaurar')
  @Permisos(PermisoBanderas.PRODUCTOS_RESTAURAR)
  @ApiOperation({ summary: 'Restaurar producto eliminado (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  restaurar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.productosLogic.restaurar(id, dto.idUsuarioAuditoria);
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
