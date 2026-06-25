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
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { AsignarUsuarioRolDto } from '../dto/asignar-usuario-rol.dto';
import { FiltroUsuariosRolesDto } from '../dto/usuarios-roles.dto';
import { UsuariosRolesLogic } from '../logic/usuarios-roles.logic';

@ApiTags('Auth - Usuarios Roles')
@Controller('auth/usuarios-roles')
export class UsuariosRolesController {
  constructor(private readonly usuariosRolesLogic: UsuariosRolesLogic) {}

  @Get()
  @ApiOperation({ summary: 'Listar asignaciones usuario-rol' })
  listar(@Query() filtros: FiltroUsuariosRolesDto) {
    return this.usuariosRolesLogic.listar(filtros);
  }

  @Post()
  @ApiOperation({ summary: 'Asignar rol a usuario' })
  asignar(@Body() dto: AsignarUsuarioRolDto) {
    return this.usuariosRolesLogic.asignar(dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Quitar rol de usuario' })
  quitar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.usuariosRolesLogic.quitar(id, dto.idUsuarioAuditoria);
  }
}
