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
import { CreateEjemploDto, UpdateEjemploDto } from '../dto/ejemplos.dto';
import { EjemploLogic } from '../logic/ejemplo.logic';

@ApiTags('Ejemplo')
@Controller('ejemplo')
export class EjemploController {
  constructor(private readonly ejemploLogic: EjemploLogic) {}

  @Get()
  @Permisos(PermisoBanderas.EJEMPLOS_LISTAR)
  @ApiOperation({ summary: 'Listar ejemplos' })
  listar(@Query() filtros: FiltroPaginacionDto) {
    return this.ejemploLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.EJEMPLOS_VER)
  @ApiOperation({ summary: 'Obtener ejemplo por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.ejemploLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.EJEMPLOS_CREAR)
  @ApiOperation({ summary: 'Crear ejemplo' })
  crear(@Body() dto: CreateEjemploDto) {
    return this.ejemploLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.EJEMPLOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar ejemplo' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateEjemploDto,
  ) {
    return this.ejemploLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.EJEMPLOS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar ejemplo (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.ejemploLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
