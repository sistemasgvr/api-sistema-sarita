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
import { AsignarUsuarioRolDto } from '../dto/asignar-usuario-rol.dto';
import { FiltroUsuariosRolesDto } from '../dto/usuarios-roles.dto';
import { UsuariosRolesLogic } from '../logic/usuarios-roles.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Auth - Usuarios Roles')
@Controller('auth/usuarios-roles')
export class UsuariosRolesController {
  constructor(private readonly usuariosRolesLogic: UsuariosRolesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.USUARIOS_ROLES_LISTAR)
  @ApiOperation({ summary: 'Listar asignaciones usuario-rol' })
  listar(@Query() filtros: FiltroUsuariosRolesDto) {
    return this.usuariosRolesLogic.listar(filtros);
  }

  @Post()
  @Permisos(PermisoBanderas.USUARIOS_ROLES_ASIGNAR)
  @ApiOperation({ summary: 'Asignar rol a usuario' })
  asignar(@Body() dto: AsignarUsuarioRolDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.usuariosRolesLogic.asignar(dto, req.user.permisos);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.USUARIOS_ROLES_QUITAR)
  @ApiOperation({ summary: 'Quitar rol de usuario' })
  quitar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.usuariosRolesLogic.quitar(id, dto.idUsuarioAuditoria);
  }
}
