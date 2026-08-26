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
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { CajaLogic } from '../logic/caja.logic';
import {
  AbrirCajaDto,
  ActualizarCajaGastoDto,
  CerrarCajaDto,
  CrearCajaDepositoDto,
  CrearCajaGastoDto,
  CrearCajaObservacionDto,
  FiltroCajaDiaDto,
  FiltroCajaGastosDto,
  FiltroCajaSesionesDto,
  FiltroLibroDiarioDto,
} from '../dto/caja.dto';

@ApiTags('Caja / Libro diario')
@Controller('caja')
export class CajaController {
  constructor(private readonly cajaLogic: CajaLogic) {}

  @Get('dia')
  @Permisos(PermisoBanderas.CAJA_VER)
  @ApiOperation({ summary: 'Snapshot de caja del día (sesión + totales)' })
  obtenerDia(@Query() query: FiltroCajaDiaDto) {
    return this.cajaLogic.obtenerDia(query.fecha, query.idSucursal);
  }

  @Get('sesiones')
  @Permisos(PermisoBanderas.CAJA_VER)
  @ApiOperation({ summary: 'Listar sesiones de caja' })
  listarSesiones(@Query() filtros: FiltroCajaSesionesDto) {
    return this.cajaLogic.listarSesiones(filtros);
  }

  @Get('pendiente-cierre')
  @Permisos(PermisoBanderas.CAJA_VER)
  @ApiOperation({
    summary: 'Cajas ABIERTA de días anteriores (pendientes de arqueo / cierre diario)',
  })
  listarPendienteCierre(@Query('idSucursal') idSucursal?: string) {
    const parsed =
      idSucursal != null && idSucursal !== '' ? Number(idSucursal) : undefined;
    return this.cajaLogic.listarPendienteCierre(
      Number.isFinite(parsed) ? parsed : undefined,
    );
  }

  @Get('sesiones/:id')
  @Permisos(PermisoBanderas.CAJA_VER)
  @ApiOperation({ summary: 'Obtener sesión de caja con totales' })
  obtenerSesion(@Param('id', ParseIntPipe) id: number) {
    return this.cajaLogic.obtenerSesion(id);
  }

  @Post('sesiones/abrir')
  @Permisos(PermisoBanderas.CAJA_ABRIR)
  @ApiOperation({ summary: 'Abrir sesión de caja' })
  abrir(@Body() dto: AbrirCajaDto) {
    return this.cajaLogic.abrirSesion(dto);
  }

  @Patch('sesiones/:id/cerrar')
  @Permisos(PermisoBanderas.CAJA_CERRAR)
  @ApiOperation({ summary: 'Cerrar / arquear sesión de caja' })
  cerrar(@Param('id', ParseIntPipe) id: number, @Body() dto: CerrarCajaDto) {
    return this.cajaLogic.cerrarSesion(id, dto);
  }

  @Get('gastos')
  @Permisos(PermisoBanderas.CAJA_VER)
  @ApiOperation({ summary: 'Listar gastos de caja (filtrable por categoría, fecha, sesión)' })
  listarGastos(@Query() filtros: FiltroCajaGastosDto) {
    return this.cajaLogic.listarGastos(filtros);
  }

  @Get('gastos/:id')
  @Permisos(PermisoBanderas.CAJA_VER)
  @ApiOperation({ summary: 'Obtener un gasto de caja por id' })
  obtenerGasto(@Param('id', ParseIntPipe) id: number) {
    return this.cajaLogic.obtenerGasto(id);
  }

  @Post('gastos')
  @Permisos(PermisoBanderas.CAJA_REGISTRAR_GASTO)
  @ApiOperation({ summary: 'Registrar gasto menudo de caja' })
  crearGasto(@Body() dto: CrearCajaGastoDto) {
    return this.cajaLogic.crearGasto(dto);
  }

  @Patch('gastos/:id')
  @Permisos(PermisoBanderas.CAJA_REGISTRAR_GASTO)
  @ApiOperation({ summary: 'Editar gasto de caja (solo mientras la caja esté abierta)' })
  actualizarGasto(@Param('id', ParseIntPipe) id: number, @Body() dto: ActualizarCajaGastoDto) {
    return this.cajaLogic.actualizarGasto(id, dto);
  }

  @Delete('gastos/:id')
  @Permisos(PermisoBanderas.CAJA_REGISTRAR_GASTO)
  @ApiOperation({ summary: 'Eliminar (baja lógica) gasto de caja' })
  eliminarGasto(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.cajaLogic.eliminarGasto(id, dto.idUsuarioAuditoria);
  }

  @Post('depositos')
  @Permisos(PermisoBanderas.CAJA_REGISTRAR_DEPOSITO)
  @ApiOperation({ summary: 'Registrar depósito a banco desde caja' })
  crearDeposito(@Body() dto: CrearCajaDepositoDto) {
    return this.cajaLogic.crearDeposito(dto);
  }

  @Delete('depositos/:id')
  @Permisos(PermisoBanderas.CAJA_REGISTRAR_DEPOSITO)
  @ApiOperation({ summary: 'Eliminar (baja lógica) depósito de caja' })
  eliminarDeposito(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.cajaLogic.eliminarDeposito(id, dto.idUsuarioAuditoria);
  }

  @Post('observaciones')
  @Permisos(PermisoBanderas.CAJA_OBSERVACION)
  @ApiOperation({ summary: 'Registrar observación del libro diario' })
  crearObservacion(@Body() dto: CrearCajaObservacionDto) {
    return this.cajaLogic.crearObservacion(dto);
  }

  @Delete('observaciones/:id')
  @Permisos(PermisoBanderas.CAJA_OBSERVACION)
  @ApiOperation({ summary: 'Eliminar observación del libro diario' })
  eliminarObservacion(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.cajaLogic.eliminarObservacion(id, dto.idUsuarioAuditoria);
  }

  @Get('libro-diario')
  @Permisos(PermisoBanderas.CAJA_LIBRO_DIARIO)
  @ApiOperation({
    summary: 'Libro diario operativo (ventas + cobranzas + gastos + depósitos + observaciones)',
    description:
      'No confundir con Resumen diario SUNAT. Agrega datos existentes + movimientos de caja del día/rango.',
  })
  libroDiario(@Query() filtros: FiltroLibroDiarioDto) {
    return this.cajaLogic.obtenerLibroDiario(filtros);
  }
}
