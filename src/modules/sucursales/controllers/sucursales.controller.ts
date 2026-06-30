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
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import { CreateSucursalDto, UpdateSucursalDto } from '../dto/sucursales.dto';
import { SucursalesLogic } from '../logic/sucursales.logic';

@ApiTags('Configuracion - Sucursales')
@Controller('configuracion/sucursales')
export class SucursalesController {
  constructor(private readonly sucursalesLogic: SucursalesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.SUCURSALES_LISTAR)
  @ApiOperation({ summary: 'Listar sucursales' })
  listar(@Query() filtros: FiltroPaginacionDto) {
    return this.sucursalesLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.SUCURSALES_VER)
  @ApiOperation({ summary: 'Obtener sucursal por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.sucursalesLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.SUCURSALES_CREAR)
  @ApiOperation({ summary: 'Crear sucursal' })
  crear(@Body() dto: CreateSucursalDto) {
    return this.sucursalesLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.SUCURSALES_EDITAR)
  @ApiOperation({ summary: 'Actualizar sucursal' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateSucursalDto,
  ) {
    return this.sucursalesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.SUCURSALES_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar sucursal (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.sucursalesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
