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
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { CreateRolDto, UpdateRolDto } from '../dto/roles.dto';
import { RolesLogic } from '../logic/roles.logic';

@ApiTags('Auth - Roles')
@Controller('auth/roles')
export class RolesController {
  constructor(private readonly rolesLogic: RolesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ROLES_LISTAR)
  @ApiOperation({ summary: 'Listar roles' })
  listar(@Query() filtros: FiltroPaginacionDto) {
    return this.rolesLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ROLES_VER)
  @ApiOperation({ summary: 'Obtener rol por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.rolesLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.ROLES_CREAR)
  @ApiOperation({ summary: 'Crear rol' })
  crear(@Body() dto: CreateRolDto) {
    return this.rolesLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ROLES_EDITAR)
  @ApiOperation({ summary: 'Actualizar rol' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateRolDto) {
    return this.rolesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ROLES_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar rol (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.rolesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
