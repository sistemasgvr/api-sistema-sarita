import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Put,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBody,
  ApiConsumes,
  ApiNotFoundResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import {
  FiltroProductoImagenesDto,
  ProductoImagenAuditoriaDto,
  UpdateProductoImagenDto,
} from '../dto/producto-imagenes.dto';
import { ProductoImagenesLogic } from '../logic/producto-imagenes.logic';

@ApiTags('Producto - Imágenes')
@Controller()
export class ProductoImagenesController {
  constructor(private readonly productoImagenesLogic: ProductoImagenesLogic) {}

  @Get('productos/:idProducto/imagenes')
  @Permisos(PermisoBanderas.PRODUCTOS_VER)
  @ApiOperation({ summary: 'Listar catálogo de imágenes de un producto' })
  listar(
    @Param('idProducto', ParseIntPipe) idProducto: number,
    @Query() filtros: FiltroProductoImagenesDto,
  ) {
    return this.productoImagenesLogic.listar(idProducto, filtros);
  }

  @Post('productos/:idProducto/imagenes')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({
    summary: 'Subir imagen al storage y asociarla al catálogo del producto',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: {
        file: { type: 'string', format: 'binary' },
        orden: { type: 'integer', example: 0 },
        esPrincipal: { type: 'boolean', example: false },
        idUsuarioAuditoria: { type: 'integer', example: 1 },
      },
    },
  })
  @UseInterceptors(FileInterceptor('file'))
  crear(
    @Param('idProducto', ParseIntPipe) idProducto: number,
    @UploadedFile() file: Express.Multer.File,
    @Body('orden') orden?: string,
    @Body('esPrincipal') esPrincipal?: string,
    @Body('idUsuarioAuditoria') idUsuarioAuditoria?: string,
  ) {
    return this.productoImagenesLogic.crear(
      idProducto,
      file,
      orden !== undefined && orden !== '' ? Number(orden) : undefined,
      esPrincipal === 'true' || esPrincipal === '1',
      idUsuarioAuditoria ? Number(idUsuarioAuditoria) : undefined,
    );
  }

  @Get('producto-imagenes/:id')
  @Permisos(PermisoBanderas.PRODUCTOS_VER)
  @ApiOperation({ summary: 'Obtener imagen de producto por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.productoImagenesLogic.obtenerPorId(id);
  }

  @Patch('producto-imagenes/:id')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({
    summary: 'Actualizar orden / imagen principal (sin cambiar el archivo)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateProductoImagenDto,
  ) {
    return this.productoImagenesLogic.actualizar(id, dto);
  }

  @Put('producto-imagenes/:id/archivo')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({
    summary:
      'Reemplazar archivo de la imagen (sube el nuevo y elimina el anterior del storage)',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: {
        file: { type: 'string', format: 'binary' },
        idUsuarioAuditoria: { type: 'integer', example: 1 },
      },
    },
  })
  @UseInterceptors(FileInterceptor('file'))
  reemplazarArchivo(
    @Param('id', ParseIntPipe) id: number,
    @UploadedFile() file: Express.Multer.File,
    @Body('idUsuarioAuditoria') idUsuarioAuditoria?: string,
  ) {
    return this.productoImagenesLogic.reemplazarArchivo(
      id,
      file,
      idUsuarioAuditoria ? Number(idUsuarioAuditoria) : undefined,
    );
  }

  @Delete('producto-imagenes/:id')
  @Permisos(PermisoBanderas.PRODUCTOS_EDITAR)
  @ApiOperation({
    summary: 'Eliminar imagen del catálogo y borrar el archivo del storage',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ProductoImagenAuditoriaDto,
  ) {
    return this.productoImagenesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
