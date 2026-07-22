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
  CreateAlquileresBalonDto,
  FiltroAlquileresAntiguedadDto,
  FiltroAlquileresBalonDto,
  UpdateAlquileresBalonDto,
} from '../dto/alquileres-balon.dto';
import { AlquileresBalonLogic } from '../logic/alquileres-balon.logic';

@ApiTags('Balones - Alquileres')
@Controller('balones/alquileres')
export class AlquileresBalonController {
  constructor(private readonly logic: AlquileresBalonLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ALQUILERES_BALON_LISTAR)
  @ApiOperation({ summary: 'Listar' })
  listar(@Query() filtros: FiltroAlquileresBalonDto) {
    return this.logic.listar(filtros);
  }

  @Get('reporte/antiguedad')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_LISTAR)
  @ApiOperation({ summary: 'Reporte de antigüedad de alquileres pendientes' })
  reporteAntiguedad(@Query() filtros: FiltroAlquileresAntiguedadDto) {
    return this.logic.reporteAntiguedad(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_VER)
  @ApiOperation({ summary: 'Obtener por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.ALQUILERES_BALON_CREAR)
  @ApiOperation({ summary: 'Crear' })
  crear(@Body() dto: CreateAlquileresBalonDto) {
    return this.logic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_EDITAR)
  @ApiOperation({ summary: 'Actualizar' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAlquileresBalonDto,
  ) {
    return this.logic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
