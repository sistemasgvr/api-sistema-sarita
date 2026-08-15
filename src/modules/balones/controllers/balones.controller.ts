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
import {
  AprobarBajaBalonDto,
  CreateBalonesDto,
  DarBajaBalonDto,
  FiltroBalonesDto,
  FiltroBalonesPropietarioDto,
  FiltroEstadoHistorialDto,
  FiltroPhHistorialDto,
  FiltroStockGasDto,
  RechazarBajaBalonDto,
  RegistrarPhHistorialDto,
  RestaurarBalonDto,
  UpdateBalonesDto,
} from '../dto/balones.dto';
import { BalonesLogic } from '../logic/balones.logic';

@ApiTags('Balones')
@Controller('balones')
export class BalonesController {
  constructor(private readonly logic: BalonesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.BALONES_LISTAR)
  @ApiOperation({ summary: 'Listar' })
  listar(@Query() filtros: FiltroBalonesDto) {
    return this.logic.listar(filtros);
  }

  @Get('stock-gas')
  @Permisos(PermisoBanderas.BALONES_LISTAR)
  @ApiOperation({
    summary:
      'Stock de gas físico: suma de capacidades de cilindros EMPRESA LLENOS en almacén',
  })
  listarStockGas(@Query() filtros: FiltroStockGasDto) {
    return this.logic.listarStockGas(filtros);
  }

  @Get('reporte/propietario')
  @Permisos(PermisoBanderas.BALONES_LISTAR)
  @ApiOperation({
    summary:
      'Reporte de cilindros por propietario (conteos EMPRESA / PLANTA / CLIENTE + detalle)',
  })
  reportePropietario(@Query() filtros: FiltroBalonesPropietarioDto) {
    return this.logic.reportePropietario(filtros);
  }

  @Get('bajas/pendientes')
  @Permisos(PermisoBanderas.BAJAS_BALON_LISTAR)
  @ApiOperation({ summary: 'Listar solicitudes de baja pendientes de aprobación' })
  listarBajasPendientes(@Query() filtros: FiltroPaginacionDto) {
    return this.logic.listarSolicitudesBaja(filtros);
  }

  @Post('bajas/:idBaja/aprobar')
  @Permisos(PermisoBanderas.BAJAS_BALON_APROBAR)
  @ApiOperation({
    summary:
      'Aprobar solicitud de baja (administrador + bajas_balon.aprobar; permite auto-aprobación)',
  })
  aprobarBaja(
    @Param('idBaja', ParseIntPipe) idBaja: number,
    @Body() dto: AprobarBajaBalonDto,
  ) {
    return this.logic.aprobarBaja(idBaja, dto);
  }

  @Post('bajas/:idBaja/rechazar')
  @Permisos(PermisoBanderas.BAJAS_BALON_RECHAZAR)
  @ApiOperation({
    summary: 'Rechazar solicitud de baja (administrador + bajas_balon.rechazar)',
  })
  rechazarBaja(
    @Param('idBaja', ParseIntPipe) idBaja: number,
    @Body() dto: RechazarBajaBalonDto,
  ) {
    return this.logic.rechazarBaja(idBaja, dto);
  }

  @Get(':id/ph-historial')
  @Permisos(PermisoBanderas.BALONES_VER)
  @ApiOperation({ summary: 'Listar historial de pruebas hidrostáticas' })
  listarPhHistorial(
    @Param('id', ParseIntPipe) id: number,
    @Query() filtros: FiltroPhHistorialDto,
  ) {
    return this.logic.listarPhHistorial(id, filtros);
  }

  @Post(':id/ph-historial')
  @Permisos(PermisoBanderas.BALONES_EDITAR)
  @ApiOperation({ summary: 'Registrar prueba hidrostática' })
  registrarPhHistorial(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RegistrarPhHistorialDto,
  ) {
    return this.logic.registrarPhHistorial(id, dto);
  }

  @Get(':id/estado-historial')
  @Permisos(PermisoBanderas.BALONES_VER)
  @ApiOperation({ summary: 'Listar historial de bajas y reactivaciones' })
  listarEstadoHistorial(
    @Param('id', ParseIntPipe) id: number,
    @Query() filtros: FiltroEstadoHistorialDto,
  ) {
    return this.logic.listarEstadoHistorial(id, filtros);
  }

  @Get(':id/baja')
  @Permisos(PermisoBanderas.BAJAS_BALON_VER)
  @ApiOperation({ summary: 'Obtener baja activa del cilindro' })
  obtenerBaja(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerBajaPorBalon(id);
  }

  @Post(':id/baja')
  @Permisos(PermisoBanderas.BAJAS_BALON_SOLICITAR)
  @ApiOperation({ summary: 'Solicitar baja de cilindro (requiere aprobación de administrador)' })
  darBaja(@Param('id', ParseIntPipe) id: number, @Body() dto: DarBajaBalonDto) {
    return this.logic.darBaja(id, dto);
  }

  @Post(':id/restaurar')
  @Permisos(PermisoBanderas.BALONES_EDITAR)
  @ApiOperation({ summary: 'Reactivar cilindro dado de baja o reportado como robo' })
  restaurar(@Param('id', ParseIntPipe) id: number, @Body() dto: RestaurarBalonDto) {
    return this.logic.restaurar(id, dto);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.BALONES_VER)
  @ApiOperation({ summary: 'Obtener por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.BALONES_CREAR)
  @ApiOperation({ summary: 'Crear' })
  crear(@Body() dto: CreateBalonesDto) {
    return this.logic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.BALONES_EDITAR)
  @ApiOperation({ summary: 'Actualizar' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateBalonesDto,
  ) {
    return this.logic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.BALONES_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
