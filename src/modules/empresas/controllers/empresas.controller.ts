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
import { CreateEmpresaDto, UpdateEmpresaDto } from '../dto/empresas.dto';
import { EmpresasLogic } from '../logic/empresas.logic';

@ApiTags('Configuracion - Empresas')
@Controller('configuracion/empresas')
export class EmpresasController {
  constructor(private readonly empresasLogic: EmpresasLogic) {}

  @Get()
  @Permisos(PermisoBanderas.EMPRESAS_LISTAR)
  @ApiOperation({ summary: 'Listar empresas' })
  listar(@Query() filtros: FiltroPaginacionDto) {
    return this.empresasLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.EMPRESAS_VER)
  @ApiOperation({ summary: 'Obtener empresa por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.empresasLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.EMPRESAS_CREAR)
  @ApiOperation({ summary: 'Crear empresa' })
  crear(@Body() dto: CreateEmpresaDto) {
    return this.empresasLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.EMPRESAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar empresa' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateEmpresaDto,
  ) {
    return this.empresasLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.EMPRESAS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar empresa (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.empresasLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
