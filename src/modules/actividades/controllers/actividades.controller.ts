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
import {
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  AsignarResponsableActividadDto,
  CreateActividadDto,
  CrearRecojoOrigenDto,
  FiltroActividadesDto,
  FiltroActividadesProximasDto,
  UpdateActividadDto,
  CrearRecojoPrestamoDto,
  FiltroRankingActividadesDto,
  FiltroVencidosRecojoDto,
  GenerarRecojosDto,
  IniciarVerificacionDto,
  VerificarActividadDto,
} from '../dto/actividades.dto';
import { ActividadesLogic } from '../logic/actividades.logic';

@ApiTags('Operativa - Actividades')
@Controller('operativa/actividades')
export class ActividadesController {
  constructor(private readonly actividadesLogic: ActividadesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ACTIVIDADES_LISTAR)
  @ApiOperation({ summary: 'Listar actividades de la agenda' })
  listar(@Query() filtros: FiltroActividadesDto) {
    return this.actividadesLogic.listar(filtros);
  }

  @Get('proximas')
  @Permisos(PermisoBanderas.ACTIVIDADES_LISTAR)
  @ApiOperation({
    summary: 'Actividades en curso o próximas (hoy, hora actual)',
  })
  listarProximas(@Query() filtros: FiltroActividadesProximasDto) {
    return this.actividadesLogic.listarProximas(filtros.minutos ?? 60);
  }

  @Get('ranking')
  @Permisos(PermisoBanderas.ACTIVIDADES_RANKING)
  @ApiOperation({
    summary: 'Ranking de colaboradores por actividades en un rango de fechas',
  })
  ranking(@Query() filtros: FiltroRankingActividadesDto) {
    return this.actividadesLogic.ranking(filtros);
  }

  @Get('vencidos-recojo')
  @Permisos(PermisoBanderas.ACTIVIDADES_LISTAR)
  @ApiOperation({
    summary:
      'Préstamos y alquileres vencidos disponibles para programar recojo',
  })
  listarVencidosRecojo(@Query() filtros: FiltroVencidosRecojoDto) {
    return this.actividadesLogic.listarVencidosRecojo(filtros);
  }

  @Post('recojo')
  @Permisos(PermisoBanderas.ACTIVIDADES_CREAR)
  @ApiOperation({
    summary:
      'Crea actividad RECOJO desde un préstamo o alquiler vencido (solo FK)',
  })
  crearRecojo(@Body() dto: CrearRecojoOrigenDto) {
    return this.actividadesLogic.crearRecojoOrigen(dto);
  }

  @Post('recojo-prestamo')
  @Permisos(PermisoBanderas.ACTIVIDADES_CREAR)
  @ApiOperation({
    summary:
      'Alias: crea recojo de un préstamo (delegado a age_crear_recojo_origen)',
  })
  crearRecojoPrestamo(@Body() dto: CrearRecojoPrestamoDto) {
    return this.actividadesLogic.crearRecojoPrestamo(dto);
  }

  @Post('generar-recojos')
  @Permisos(PermisoBanderas.ACTIVIDADES_CREAR)
  @ApiOperation({
    summary:
      'Genera las actividades de recojo de los préstamos vencidos o por vencer',
  })
  generarRecojos(@Body() dto: GenerarRecojosDto) {
    return this.actividadesLogic.generarRecojosPorVencer(dto);
  }

  @Post(':id/iniciar-verificacion')
  @Permisos(PermisoBanderas.ACTIVIDADES_VERIFICAR)
  @ApiOperation({
    summary:
      'Materializa ítems del origen (préstamo/alquiler) antes del escaneo',
  })
  iniciarVerificacion(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: IniciarVerificacionDto,
  ) {
    return this.actividadesLogic.iniciarVerificacion(
      id,
      dto.idUsuarioAuditoria,
    );
  }

  @Post(':id/verificar')
  @Permisos(PermisoBanderas.ACTIVIDADES_VERIFICAR)
  @ApiOperation({
    summary:
      'Verifica por escaneo los ítems de la actividad (salida o llegada)',
  })
  verificar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: VerificarActividadDto,
  ) {
    return this.actividadesLogic.verificar(id, dto);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ACTIVIDADES_VER)
  @ApiOperation({ summary: 'Obtener actividad por ID' })
  @ApiOkResponse({ description: 'Actividad obtenida correctamente' })
  @ApiNotFoundResponse({
    description: 'La actividad solicitada no existe o fue eliminada',
  })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.actividadesLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.ACTIVIDADES_CREAR)
  @ApiOperation({ summary: 'Crear actividad' })
  crear(@Body() dto: CreateActividadDto) {
    return this.actividadesLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ACTIVIDADES_EDITAR)
  @ApiOperation({ summary: 'Actualizar actividad' })
  @ApiOkResponse({ description: 'Actividad actualizada correctamente' })
  @ApiNotFoundResponse({
    description: 'La actividad que intenta actualizar no existe',
  })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateActividadDto,
  ) {
    return this.actividadesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ACTIVIDADES_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar actividad (baja lógica)' })
  @ApiOkResponse({ description: 'Actividad eliminada correctamente' })
  @ApiNotFoundResponse({
    description:
      'La actividad que intenta eliminar no existe o ya fue dada de baja',
  })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.actividadesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }

  @Patch(':id/realizada')
  @Permisos(PermisoBanderas.ACTIVIDADES_EDITAR)
  @ApiOperation({ summary: 'Marcar actividad como realizada' })
  marcarComoRealizada(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.actividadesLogic.marcarComoRealizada(
      id,
      dto.idUsuarioAuditoria,
    );
  }

  @Patch(':id/cancelar')
  @Permisos(PermisoBanderas.ACTIVIDADES_EDITAR)
  @ApiOperation({ summary: 'Cancelar actividad / reparto' })
  cancelar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.actividadesLogic.cancelar(id, dto.idUsuarioAuditoria);
  }

  @Patch(':id/responsable')
  @Permisos(PermisoBanderas.ACTIVIDADES_EDITAR)
  @ApiOperation({
    summary:
      'Asignar o liberar el responsable de la actividad (tomar / liberar)',
  })
  asignarResponsable(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AsignarResponsableActividadDto,
  ) {
    return this.actividadesLogic.asignarResponsable(
      id,
      dto.idUsuarioAuditoria,
      dto.idTrabajadorResponsable ?? null,
    );
  }
}
