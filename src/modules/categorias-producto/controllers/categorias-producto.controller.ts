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
  CreateCategoriaProductoDto,
  FiltroCategoriasProductoDto,
  UpdateCategoriaProductoDto,
} from '../dto/categorias-producto.dto';
import { CategoriasProductoLogic } from '../logic/categorias-producto.logic';

@ApiTags('Productos - Categorías')
@Controller('productos/categorias')
export class CategoriasProductoController {
  constructor(private readonly categoriasProductoLogic: CategoriasProductoLogic) {}

  @Get()
  @Permisos(PermisoBanderas.CATEGORIAS_LISTAR)
  @ApiOperation({ summary: 'Listar categorías de producto' })
  listar(@Query() filtros: FiltroCategoriasProductoDto) {
    return this.categoriasProductoLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CATEGORIAS_VER)
  @ApiOperation({ summary: 'Obtener categoría por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.categoriasProductoLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.CATEGORIAS_CREAR)
  @ApiOperation({ summary: 'Crear categoría de producto' })
  crear(@Body() dto: CreateCategoriaProductoDto) {
    return this.categoriasProductoLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CATEGORIAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar categoría de producto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateCategoriaProductoDto,
  ) {
    return this.categoriasProductoLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CATEGORIAS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar categoría (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.categoriasProductoLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
