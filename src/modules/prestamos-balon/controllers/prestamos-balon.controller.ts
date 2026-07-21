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
  CreatePrestamosBalonDto,
  FiltroPrestamosAntiguedadDto,
  FiltroPrestamosBalonDto,
  UpdatePrestamosBalonDto,
} from '../dto/prestamos-balon.dto';
import { PrestamosBalonLogic } from '../logic/prestamos-balon.logic';

@ApiTags('Balones - Préstamos')
@Controller('balones/prestamos')
export class PrestamosBalonController {
  constructor(private readonly logic: PrestamosBalonLogic) {}

  @Get()
  @Permisos(PermisoBanderas.PRESTAMOS_BALON_LISTAR)
  @ApiOperation({ summary: 'Listar' })
  listar(@Query() filtros: FiltroPrestamosBalonDto) {
    return this.logic.listar(filtros);
  }

  @Get('reporte/antiguedad')
  @Permisos(PermisoBanderas.PRESTAMOS_BALON_LISTAR)
  @ApiOperation({
    summary:
      'Reporte de cilindros en préstamo por antigüedad (30 / 90–180 / 180+ días)',
  })
  reporteAntiguedad(@Query() filtros: FiltroPrestamosAntiguedadDto) {
    return this.logic.reporteAntiguedad(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.PRESTAMOS_BALON_VER)
  @ApiOperation({ summary: 'Obtener por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.PRESTAMOS_BALON_CREAR)
  @ApiOperation({ summary: 'Crear' })
  crear(@Body() dto: CreatePrestamosBalonDto) {
    return this.logic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.PRESTAMOS_BALON_EDITAR)
  @ApiOperation({ summary: 'Actualizar' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdatePrestamosBalonDto,
  ) {
    return this.logic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.PRESTAMOS_BALON_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
