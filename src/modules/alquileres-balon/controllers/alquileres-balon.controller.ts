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
  RegistrarAlquilerPeriodoDto,
  RenovarAlquilerDto,
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
  @ApiOperation({ summary: 'Reporte de días de atraso de alquileres pendientes' })
  reporteAntiguedad(@Query() filtros: FiltroAlquileresAntiguedadDto) {
    return this.logic.reporteAntiguedad(filtros);
  }

  @Get(':id/periodos')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_VER)
  @ApiOperation({ summary: 'Listar periodos / renovaciones del alquiler' })
  listarPeriodos(
    @Param('id', ParseIntPipe) id: number,
    @Query('pagina') pagina?: string,
    @Query('limite') limite?: string,
  ) {
    return this.logic.listarPeriodos(
      id,
      Number(pagina) || 1,
      Number(limite) || 100,
    );
  }

  @Post(':id/periodos')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_CREAR)
  @ApiOperation({ summary: 'Registrar periodo (kit o renovación ya cobrada)' })
  registrarPeriodo(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RegistrarAlquilerPeriodoDto,
  ) {
    return this.logic.registrarPeriodo(id, dto);
  }

  @Post(':id/renovar')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_EDITAR)
  @ApiOperation({ summary: 'Renovar periodo quincenal del regulador' })
  renovar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RenovarAlquilerDto,
  ) {
    return this.logic.renovar(id, dto);
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
