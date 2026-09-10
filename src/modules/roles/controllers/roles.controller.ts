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
  Req,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { CreateRolDto, UpdateRolDto } from '../dto/roles.dto';
import { RolesLogic } from '../logic/roles.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

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
  crear(@Body() dto: CreateRolDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.rolesLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ROLES_EDITAR)
  @ApiOperation({ summary: 'Actualizar rol' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateRolDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.rolesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ROLES_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar rol (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.rolesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
