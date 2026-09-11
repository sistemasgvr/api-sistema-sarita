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
  Req,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import {
  CreateAlquileresBalonDto,
  FiltroAlquileresAntiguedadDto,
  FiltroAlquileresBalonDto,
  RegistrarAlquilerPeriodoDto,
  DevolverReguladorAlquilerDto,
  RenovarAlquilerDto,
  UpdateAlquileresBalonDto,
} from '../dto/alquileres-balon.dto';
import { AlquileresBalonLogic } from '../logic/alquileres-balon.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

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

  @Get('siguiente-numero')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_CREAR)
  @ApiOperation({ summary: 'Obtener próximo número correlativo ALQ-YYYY-###' })
  obtenerSiguienteNumero(@Query('anio') anio?: string) {
    const parsed = anio != null && anio !== '' ? Number(anio) : undefined;
    return this.logic.obtenerSiguienteNumero(
      Number.isFinite(parsed) ? parsed : undefined,
    );
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
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.registrarPeriodo(id, dto);
  }

  @Post(':id/devolver-regulador')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_EDITAR)
  @ApiOperation({
    summary: 'Devolver el regulador/accesorio alquilado (finaliza el alquiler)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  devolverRegulador(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: DevolverReguladorAlquilerDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.devolverRegulador(id, dto);
  }

  @Post(':id/renovar')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_EDITAR)
  @ApiOperation({ summary: 'Renovar periodo quincenal del regulador' })
  renovar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RenovarAlquilerDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
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
  crear(@Body() dto: CreateAlquileresBalonDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_EDITAR)
  @ApiOperation({ summary: 'Actualizar' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAlquileresBalonDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ALQUILERES_BALON_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
