import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { AsignarRolPermisoDto } from '../dto/asignar-rol-permiso.dto';
import { FiltroRolesPermisosDto } from '../dto/roles-permisos.dto';
import { RolesPermisosLogic } from '../logic/roles-permisos.logic';

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
  asignar(@Body() dto: AsignarRolPermisoDto) {
    return this.rolesPermisosLogic.asignar(dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ROLES_PERMISOS_QUITAR)
  @ApiOperation({ summary: 'Quitar permiso de rol' })
  quitar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.rolesPermisosLogic.quitar(id, dto.idUsuarioAuditoria);
  }
}
