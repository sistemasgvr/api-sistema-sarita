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
import { CreateRolDto, UpdateRolDto } from '../dto/roles.dto';
import { RolesLogic } from '../logic/roles.logic';

@ApiTags('Auth - Roles')
@Controller('auth/roles')
export class RolesController {
  constructor(private readonly rolesLogic: RolesLogic) {}

  @Get()
  @ApiOperation({ summary: 'Listar roles' })
  listar(@Query() filtros: FiltroPaginacionDto) {
    return this.rolesLogic.listar(filtros);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener rol por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.rolesLogic.obtenerPorId(id);
  }

  @Post()
  @ApiOperation({ summary: 'Crear rol' })
  crear(@Body() dto: CreateRolDto) {
    return this.rolesLogic.crear(dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Actualizar rol' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateRolDto) {
    return this.rolesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Eliminar rol (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.rolesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
