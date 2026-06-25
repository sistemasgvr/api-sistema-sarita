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
import { CreateUsuarioDto, UpdateUsuarioDto } from '../dto/usuarios.dto';
import { UsuariosLogic } from '../logic/usuarios.logic';

@ApiTags('Auth - Usuarios')
@Controller('auth/usuarios')
export class UsuariosController {
  constructor(private readonly usuariosLogic: UsuariosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.USUARIOS_LISTAR)
  @ApiOperation({ summary: 'Listar usuarios' })
  listar(@Query() filtros: FiltroPaginacionDto) {
    return this.usuariosLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.USUARIOS_VER)
  @ApiOperation({ summary: 'Obtener usuario por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.usuariosLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.USUARIOS_CREAR)
  @ApiOperation({ summary: 'Crear usuario' })
  crear(@Body() dto: CreateUsuarioDto) {
    return this.usuariosLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.USUARIOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar usuario' })
  actualizar(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateUsuarioDto) {
    return this.usuariosLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.USUARIOS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar usuario (baja lógica)' })
  eliminar(@Param('id', ParseIntPipe) id: number) {
    return this.usuariosLogic.eliminar(id);
  }
}
