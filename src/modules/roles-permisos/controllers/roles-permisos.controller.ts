import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { AsignarRolPermisoDto } from '../dto/asignar-rol-permiso.dto';
import { FiltroRolesPermisosDto } from '../dto/roles-permisos.dto';
import { RolesPermisosLogic } from '../logic/roles-permisos.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Auth - Roles Permisos')
@Controller('auth/roles-permisos')
export class RolesPermisosController {
  constructor(private readonly rolesPermisosLogic: RolesPermisosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ROLES_PERMISOS_LISTAR)
  @ApiOperation({ summary: 'Listar asignaciones rol-permiso' })
  listar(@Query() filtros: FiltroRolesPermisosDto) {
    return this.rolesPermisosLogic.listar(filtros);
  }

  @Post()
  @Permisos(PermisoBanderas.ROLES_PERMISOS_ASIGNAR)
  @ApiOperation({ summary: 'Asignar permiso a rol' })
  asignar(@Body() dto: AsignarRolPermisoDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.rolesPermisosLogic.asignar(dto, req.user.permisos);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ROLES_PERMISOS_QUITAR)
  @ApiOperation({ summary: 'Quitar permiso de rol' })
  quitar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.rolesPermisosLogic.quitar(
      id,
      dto.idUsuarioAuditoria,
      req.user.permisos,
    );
  }
}
