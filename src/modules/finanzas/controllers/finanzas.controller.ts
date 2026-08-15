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
import { FinanzasLogic } from '../logic/finanzas.logic';
import { FiltroCuentaDto } from '../dto/filtro-cuenta.dto';
import { RegistrarPagoDto } from '../dto/registrar-pago.dto';
import { CrearCuentaCuotasDto, CrearCuentaDto } from '../dto/crear-cuenta.dto';
import { ActualizarCuentaDto } from '../dto/actualizar-cuenta.dto';
import {
  ActualizarGarantiaDto,
  CrearGarantiaDto,
  FiltroGarantiaDto,
  ReembolsarGarantiaDto,
} from '../dto/garantia.dto';
import { VerificarDuplicadoPagoDto } from '../dto/verificar-duplicado.dto';
import { FiltroSaldosPorTerceroDto } from '../dto/filtro-saldos-tercero.dto';

@ApiTags('Finanzas')
@Controller('finanzas')
export class FinanzasController {
  constructor(private readonly finanzasLogic: FinanzasLogic) {}

  @Get('medios-pago')
  @ApiOperation({ summary: 'Listar medios de pago disponibles' })
  mediosPago() {
    return this.finanzasLogic.listarMediosPago();
  }

  @Post('verificar-duplicado-pago')
  @ApiOperation({
    summary: 'Verifica si un pago propuesto podría ser duplicado antes de registrar',
  })
  verificarDuplicadoPago(@Body() dto: VerificarDuplicadoPagoDto) {
    return this.finanzasLogic.verificarDuplicadoPago(dto);
  }

  // ---------------- Garantías (ven_garantia: POS / préstamos / alquileres / manual) ----------------

  @Get('garantias')
  @Permisos(PermisoBanderas.FINANZAS_GARANTIAS_VER)
  @ApiOperation({
    summary: 'Listar garantías operativas (préstamos, alquileres, POS y manuales)',
  })
  listarGarantias(@Query() filtros: FiltroGarantiaDto) {
    return this.finanzasLogic.listarGarantias(filtros);
  }

  @Get('garantias/:id')
  @Permisos(PermisoBanderas.FINANZAS_GARANTIAS_VER)
  @ApiOperation({ summary: 'Obtener garantía por ID (incluye movimientos)' })
  obtenerGarantia(@Param('id', ParseIntPipe) id: number) {
    return this.finanzasLogic.obtenerGarantia(id);
  }

  @Post('garantias')
  @Permisos(PermisoBanderas.FINANZAS_GARANTIAS_CREAR)
  @ApiOperation({ summary: 'Registrar una garantía manual (sin préstamo/alquiler/POS)' })
  crearGarantia(@Body() dto: CrearGarantiaDto) {
    return this.finanzasLogic.crearGarantia(dto);
  }

  @Patch('garantias/:id')
  @Permisos(PermisoBanderas.FINANZAS_GARANTIAS_EDITAR)
  @ApiOperation({
    summary: 'Editar una garantía manual (sin devoluciones ni vínculo operativo)',
  })
  actualizarGarantia(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ActualizarGarantiaDto,
  ) {
    return this.finanzasLogic.actualizarGarantia(id, dto);
  }

  @Delete('garantias/:id')
  @Permisos(PermisoBanderas.FINANZAS_GARANTIAS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar (baja lógica) una garantía manual' })
  eliminarGarantia(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.finanzasLogic.eliminarGarantia(id, dto.idUsuarioAuditoria);
  }

  @Post('garantias/:id/reembolsar')
  @Permisos(PermisoBanderas.FINANZAS_GARANTIAS_REEMBOLSAR)
  @ApiOperation({
    summary: 'Devolver garantía (parcial o total; actualiza saldo y estado)',
  })
  reembolsarGarantia(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ReembolsarGarantiaDto,
  ) {
    return this.finanzasLogic.reembolsarGarantia(id, dto);
  }

  // ---------------- Cuentas por Cobrar ----------------

  @Get('cuentas-por-cobrar')
  @Permisos(PermisoBanderas.FINANZAS_CXC_VER)
  @ApiOperation({ summary: 'Listar cuentas por cobrar (clientes)' })
  listarCobrar(@Query() filtros: FiltroCuentaDto) {
    return this.finanzasLogic.listarCuentas('COBRAR', filtros);
  }

  @Get('cuentas-por-cobrar/resumen')
  @Permisos(PermisoBanderas.FINANZAS_CXC_VER)
  @ApiOperation({ summary: 'Resumen (KPIs) de cuentas por cobrar' })
  resumenCobrar() {
    return this.finanzasLogic.resumen('COBRAR');
  }

  @Get('cuentas-por-cobrar/saldos-por-cliente')
  @Permisos(PermisoBanderas.FINANZAS_CXC_VER)
  @ApiOperation({
    summary: 'Saldos CxC por cliente a la fecha (debe / abonado / saldo)',
  })
  saldosCobrar(@Query() filtros: FiltroSaldosPorTerceroDto) {
    return this.finanzasLogic.listarSaldosPorTercero('COBRAR', filtros);
  }

  @Get('cuentas-por-cobrar/:id')
  @Permisos(PermisoBanderas.FINANZAS_CXC_VER)
  @ApiOperation({ summary: 'Detalle de una cuenta por cobrar con sus pagos' })
  obtenerCobrar(@Param('id', ParseIntPipe) id: number) {
    return this.finanzasLogic.obtenerCuenta(id, 'COBRAR');
  }

  @Post('cuentas-por-cobrar')
  @Permisos(PermisoBanderas.FINANZAS_CXC_CREAR)
  @ApiOperation({ summary: 'Crear una cuenta por cobrar manual (externa a ventas)' })
  crearCobrar(@Body() dto: CrearCuentaDto) {
    return this.finanzasLogic.crearCuenta('COBRAR', dto);
  }

  @Post('cuentas-por-cobrar/plan-cuotas')
  @Permisos(PermisoBanderas.FINANZAS_CXC_CREAR)
  @ApiOperation({
    summary:
      'Crear una cuenta por cobrar con plan de cuotas (venta a plazos, financiamiento, etc.)',
  })
  crearCobrarCuotas(@Body() dto: CrearCuentaCuotasDto) {
    return this.finanzasLogic.crearCuentaCuotas('COBRAR', dto);
  }

  @Post('cuentas-por-cobrar/pagos')
  @Permisos(PermisoBanderas.FINANZAS_CXC_REGISTRAR_PAGO)
  @ApiOperation({ summary: 'Registrar una cobranza sobre una cuenta por cobrar' })
  registrarCobranza(@Body() dto: RegistrarPagoDto) {
    return this.finanzasLogic.registrarPago('COBRAR', dto);
  }

  @Patch('cuentas-por-cobrar/pagos/:id/anular')
  @Permisos(PermisoBanderas.FINANZAS_CXC_REGISTRAR_PAGO)
  @ApiOperation({ summary: 'Anular una cobranza registrada' })
  anularCobranza(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.finanzasLogic.anularPago(id, 'COBRAR', dto.idUsuarioAuditoria);
  }

  @Patch('cuentas-por-cobrar/:id')
  @Permisos(PermisoBanderas.FINANZAS_CXC_EDITAR)
  @ApiOperation({ summary: 'Editar una cuenta por cobrar' })
  actualizarCobrar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ActualizarCuentaDto,
  ) {
    return this.finanzasLogic.actualizarCuenta(id, 'COBRAR', dto);
  }

  @Delete('cuentas-por-cobrar/:id')
  @Permisos(PermisoBanderas.FINANZAS_CXC_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar (baja lógica) una cuenta por cobrar' })
  eliminarCobrar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.finanzasLogic.eliminarCuenta(id, 'COBRAR', dto.idUsuarioAuditoria);
  }

  // ---------------- Cuentas por Pagar ----------------

  @Get('cuentas-por-pagar')
  @Permisos(PermisoBanderas.FINANZAS_CXP_VER)
  @ApiOperation({ summary: 'Listar cuentas por pagar (proveedores)' })
  listarPagar(@Query() filtros: FiltroCuentaDto) {
    return this.finanzasLogic.listarCuentas('PAGAR', filtros);
  }

  @Get('cuentas-por-pagar/resumen')
  @Permisos(PermisoBanderas.FINANZAS_CXP_VER)
  @ApiOperation({ summary: 'Resumen (KPIs) de cuentas por pagar' })
  resumenPagar() {
    return this.finanzasLogic.resumen('PAGAR');
  }

  @Get('cuentas-por-pagar/saldos-por-proveedor')
  @Permisos(PermisoBanderas.FINANZAS_CXP_VER)
  @ApiOperation({
    summary: 'Saldos CxP por proveedor a la fecha (debe / abonado / saldo)',
  })
  saldosPagar(@Query() filtros: FiltroSaldosPorTerceroDto) {
    return this.finanzasLogic.listarSaldosPorTercero('PAGAR', filtros);
  }

  @Get('cuentas-por-pagar/:id')
  @Permisos(PermisoBanderas.FINANZAS_CXP_VER)
  @ApiOperation({ summary: 'Detalle de una cuenta por pagar con sus pagos' })
  obtenerPagar(@Param('id', ParseIntPipe) id: number) {
    return this.finanzasLogic.obtenerCuenta(id, 'PAGAR');
  }

  @Post('cuentas-por-pagar')
  @Permisos(PermisoBanderas.FINANZAS_CXP_CREAR)
  @ApiOperation({ summary: 'Crear una cuenta por pagar manual (externa a compras)' })
  crearPagar(@Body() dto: CrearCuentaDto) {
    return this.finanzasLogic.crearCuenta('PAGAR', dto);
  }

  @Post('cuentas-por-pagar/plan-cuotas')
  @Permisos(PermisoBanderas.FINANZAS_CXP_CREAR)
  @ApiOperation({
    summary:
      'Crear una cuenta por pagar con plan de cuotas (préstamo bancario, compra a plazos, etc.)',
  })
  crearPagarCuotas(@Body() dto: CrearCuentaCuotasDto) {
    return this.finanzasLogic.crearCuentaCuotas('PAGAR', dto);
  }

  @Post('cuentas-por-pagar/pagos')
  @Permisos(PermisoBanderas.FINANZAS_CXP_REGISTRAR_PAGO)
  @ApiOperation({ summary: 'Registrar un pago sobre una cuenta por pagar' })
  registrarPago(@Body() dto: RegistrarPagoDto) {
    return this.finanzasLogic.registrarPago('PAGAR', dto);
  }

  @Patch('cuentas-por-pagar/pagos/:id/anular')
  @Permisos(PermisoBanderas.FINANZAS_CXP_REGISTRAR_PAGO)
  @ApiOperation({ summary: 'Anular un pago registrado' })
  anularPago(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.finanzasLogic.anularPago(id, 'PAGAR', dto.idUsuarioAuditoria);
  }

  @Patch('cuentas-por-pagar/:id')
  @Permisos(PermisoBanderas.FINANZAS_CXP_EDITAR)
  @ApiOperation({ summary: 'Editar una cuenta por pagar' })
  actualizarPagar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ActualizarCuentaDto,
  ) {
    return this.finanzasLogic.actualizarCuenta(id, 'PAGAR', dto);
  }

  @Delete('cuentas-por-pagar/:id')
  @Permisos(PermisoBanderas.FINANZAS_CXP_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar (baja lógica) una cuenta por pagar' })
  eliminarPagar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.finanzasLogic.eliminarCuenta(id, 'PAGAR', dto.idUsuarioAuditoria);
  }
}
