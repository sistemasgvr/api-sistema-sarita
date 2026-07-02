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
  CreateSubCategoriaProductoDto,
  FiltroSubCategoriasProductoDto,
  UpdateSubCategoriaProductoDto,
} from '../dto/sub-categorias-producto.dto';
import { SubCategoriasProductoLogic } from '../logic/sub-categorias-producto.logic';

@ApiTags('Productos - Subcategorías')
@Controller('productos/sub-categorias')
export class SubCategoriasProductoController {
  constructor(private readonly subCategoriasProductoLogic: SubCategoriasProductoLogic) {}

  @Get()
  @Permisos(PermisoBanderas.SUB_CATEGORIAS_LISTAR)
  @ApiOperation({ summary: 'Listar subcategorías de producto' })
  listar(@Query() filtros: FiltroSubCategoriasProductoDto) {
    return this.subCategoriasProductoLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.SUB_CATEGORIAS_VER)
  @ApiOperation({ summary: 'Obtener subcategoría por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.subCategoriasProductoLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.SUB_CATEGORIAS_CREAR)
  @ApiOperation({ summary: 'Crear subcategoría de producto' })
  crear(@Body() dto: CreateSubCategoriaProductoDto) {
    return this.subCategoriasProductoLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.SUB_CATEGORIAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar subcategoría de producto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateSubCategoriaProductoDto,
  ) {
    return this.subCategoriasProductoLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.SUB_CATEGORIAS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar subcategoría (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.subCategoriasProductoLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
