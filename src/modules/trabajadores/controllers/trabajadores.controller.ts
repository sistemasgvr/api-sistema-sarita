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
import {
  CreateTrabajadorDto,
  FiltroTrabajadorDto,
  UpdateTrabajadorDto,
} from '../dto/trabajadores.dto';
import { TrabajadoresLogic } from '../logic/trabajadores.logic';

@ApiTags('Trabajadores')
@Controller('trabajadores')
export class TrabajadoresController {
  constructor(private readonly trabajadoresLogic: TrabajadoresLogic) {}

  @Get()
  @Permisos(PermisoBanderas.TRABAJADOR_LISTAR)
  @ApiOperation({ summary: 'Listar trabajadores' })
  listar(@Query() filtros: FiltroTrabajadorDto) {
    return this.trabajadoresLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.TRABAJADOR_VER)
  @ApiOperation({ summary: 'Obtener trabajador por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.trabajadoresLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.TRABAJADOR_CREAR)
  @ApiOperation({ summary: 'Crear trabajador' })
  crear(@Body() dto: CreateTrabajadorDto) {
    return this.trabajadoresLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.TRABAJADOR_EDITAR)
  @ApiOperation({ summary: 'Actualizar trabajador' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateTrabajadorDto,
  ) {
    return this.trabajadoresLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.TRABAJADOR_ELIMINAR)
  @ApiOperation({ summary: 'Dar de baja a trabajador (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.trabajadoresLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
