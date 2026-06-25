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
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { CreatePermisoDto, UpdatePermisoDto } from '../dto/permisos.dto';
import { PermisosLogic } from '../logic/permisos.logic';

@ApiTags('Auth - Permisos')
@Controller('auth/permisos')
export class PermisosController {
  constructor(private readonly permisosLogic: PermisosLogic) {}

  @Get()
  @ApiOperation({ summary: 'Listar permisos' })
  listar(@Query() filtros: FiltroPaginacionDto) {
    return this.permisosLogic.listar(filtros);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener permiso por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.permisosLogic.obtenerPorId(id);
  }

  @Post()
  @ApiOperation({ summary: 'Crear permiso' })
  crear(@Body() dto: CreatePermisoDto) {
    return this.permisosLogic.crear(dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Actualizar permiso' })
  actualizar(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdatePermisoDto) {
    return this.permisosLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Eliminar permiso (baja lógica)' })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.permisosLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
