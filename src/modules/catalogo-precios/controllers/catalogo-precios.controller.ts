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
  CreateCatalogoPrecioDto,
  FiltroCatalogoPreciosDto,
  UpdateCatalogoPrecioDto,
} from '../dto/catalogo-precios.dto';
import { CatalogoPreciosLogic } from '../logic/catalogo-precios.logic';

@ApiTags('Productos - Catálogo de precios')
@Controller('productos/catalogo-precios')
export class CatalogoPreciosController {
  constructor(private readonly catalogoPreciosLogic: CatalogoPreciosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.CATALOGO_PRECIOS_LISTAR)
  @ApiOperation({ summary: 'Listar catálogo de precios' })
  listar(@Query() filtros: FiltroCatalogoPreciosDto) {
    return this.catalogoPreciosLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CATALOGO_PRECIOS_VER)
  @ApiOperation({ summary: 'Obtener ítem de catálogo por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.catalogoPreciosLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.CATALOGO_PRECIOS_CREAR)
  @ApiOperation({ summary: 'Crear ítem de catálogo de precios' })
  crear(@Body() dto: CreateCatalogoPrecioDto) {
    return this.catalogoPreciosLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CATALOGO_PRECIOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar ítem de catálogo de precios' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateCatalogoPrecioDto,
  ) {
    return this.catalogoPreciosLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CATALOGO_PRECIOS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar ítem de catálogo (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.catalogoPreciosLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
