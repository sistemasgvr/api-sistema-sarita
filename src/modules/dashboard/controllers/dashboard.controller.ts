import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { DashboardLogic } from '../logic/dashboard.logic';
import {
  BalonesKpiQueryDto,
  ClientesKpiQueryDto,
  ClientesMoraQueryDto,
  ComprasNetasQueryDto,
  DeudaKpiQueryDto,
  HistoricoQueryDto,
  IdAlmacenQueryDto,
  RangoFechasQueryDto,
  StockCriticoQueryDto,
  TopClientesVentaQueryDto,
  VelocidadSalidaQueryDto,
  VentaGasesComparativoQueryDto,
  VentasNetasQueryDto,
} from '../dto/dashboard.dto';

@ApiTags('Dashboard')
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboardLogic: DashboardLogic) {}

  @Get('clientes')
  @Permisos(PermisoBanderas.DASHBOARD_VER_CLIENTES)
  @ApiOperation({ summary: 'KPIs del módulo Clientes' })
  kpiClientes(@Query() query: ClientesKpiQueryDto) {
    return this.dashboardLogic.kpiClientes({
      idCliente: query.idCliente ?? null,
      fechaDesde: query.fechaDesde ?? null,
      fechaHasta: query.fechaHasta ?? null,
    });
  }

  @Get('balones')
  @Permisos(PermisoBanderas.DASHBOARD_VER_BALONES)
  @ApiOperation({ summary: 'KPIs del módulo Balones' })
  kpiBalones(@Query() query: BalonesKpiQueryDto) {
    return this.dashboardLogic.kpiBalones(
      query.diasAlerta ?? 30,
      query.idCliente ?? null,
    );
  }

  @Get('ventas')
  @Permisos(PermisoBanderas.DASHBOARD_VER_VENTAS)
  @ApiOperation({ summary: 'Ventas netas (boleta + factura + VSD activos)' })
  kpiVentas(@Query() query: VentasNetasQueryDto) {
    return this.dashboardLogic.kpiVentas({
      idCliente: query.idCliente ?? null,
      fechaDesde: query.fechaDesde ?? null,
      fechaHasta: query.fechaHasta ?? null,
    });
  }

  @Get('compras')
  @Permisos(PermisoBanderas.DASHBOARD_VER_COMPRAS)
  @ApiOperation({ summary: 'Compras netas (comprobantes de compra activos)' })
  kpiCompras(@Query() query: ComprasNetasQueryDto) {
    return this.dashboardLogic.kpiCompras({
      fechaDesde: query.fechaDesde ?? null,
      fechaHasta: query.fechaHasta ?? null,
    });
  }

  @Get('deudas/cobrar')
  @Permisos(PermisoBanderas.FINANZAS_CXC_VER)
  @ApiOperation({ summary: 'Resumen de deuda por cobrar con filtros' })
  kpiDeudaCobrar(@Query() query: DeudaKpiQueryDto) {
    return this.dashboardLogic.kpiDeuda('COBRAR', {
      idCliente: query.idCliente ?? null,
      fechaDesde: query.fechaDesde ?? null,
      fechaHasta: query.fechaHasta ?? null,
    });
  }

  @Get('deudas/pagar')
  @Permisos(PermisoBanderas.FINANZAS_CXP_VER)
  @ApiOperation({ summary: 'Resumen de deuda por pagar con filtros' })
  kpiDeudaPagar(@Query() query: DeudaKpiQueryDto) {
    return this.dashboardLogic.kpiDeuda('PAGAR', {
      idCliente: query.idCliente ?? null,
      fechaDesde: query.fechaDesde ?? null,
      fechaHasta: query.fechaHasta ?? null,
    });
  }

  @Get('deudas/creditos-otorgados')
  @Permisos(PermisoBanderas.FINANZAS_CXC_VER)
  @ApiOperation({ summary: 'Total de créditos (CxC) otorgados a clientes' })
  creditosOtorgados(@Query() query: RangoFechasQueryDto) {
    return this.dashboardLogic.creditosOtorgados({
      fechaDesde: query.fechaDesde ?? null,
      fechaHasta: query.fechaHasta ?? null,
    });
  }

  @Get('rentabilidad')
  @Permisos(PermisoBanderas.DASHBOARD_VER_VENTAS)
  @ApiOperation({ summary: 'Rentabilidad (ventas netas - compras netas)' })
  kpiRentabilidad(@Query() query: RangoFechasQueryDto) {
    return this.dashboardLogic.kpiRentabilidad({
      fechaDesde: query.fechaDesde ?? null,
      fechaHasta: query.fechaHasta ?? null,
    });
  }

  @Get('historico')
  @Permisos(PermisoBanderas.DASHBOARD_VER_VENTAS)
  @ApiOperation({ summary: 'Comparativo histórico mensual: ventas vs compras' })
  historico(@Query() query: HistoricoQueryDto) {
    return this.dashboardLogic.historicoVentasCompras(query.anio ?? null);
  }

  @Get('ventas/top-clientes')
  @Permisos(PermisoBanderas.DASHBOARD_VER_VENTAS)
  @ApiOperation({ summary: 'Top clientes por volumen de venta' })
  topClientesVenta(@Query() query: TopClientesVentaQueryDto) {
    return this.dashboardLogic.topClientesVenta({
      fechaDesde: query.fechaDesde ?? null,
      fechaHasta: query.fechaHasta ?? null,
      limite: query.limite ?? 10,
    });
  }

  @Get('ventas/demanda-gases')
  @Permisos(PermisoBanderas.DASHBOARD_VER_VENTAS)
  @ApiOperation({
    summary: 'Demanda de gases: % de participación por producto',
  })
  demandaGases(@Query() query: RangoFechasQueryDto) {
    return this.dashboardLogic.demandaGases({
      fechaDesde: query.fechaDesde ?? null,
      fechaHasta: query.fechaHasta ?? null,
    });
  }

  @Get('ventas/gases-comparativo')
  @Permisos(PermisoBanderas.DASHBOARD_VER_VENTAS)
  @ApiOperation({
    summary: 'Volumen de venta de gases: mes actual vs mes anterior',
  })
  ventaGasesComparativo(@Query() query: VentaGasesComparativoQueryDto) {
    return this.dashboardLogic.ventaGasesComparativo(
      query.anio ?? null,
      query.mes ?? null,
    );
  }

  @Get('clientes/mora')
  @Permisos(PermisoBanderas.DASHBOARD_VER_CLIENTES)
  @ApiOperation({ summary: 'Clientes en mora y casos urgentes (>X días)' })
  clientesMora(@Query() query: ClientesMoraQueryDto) {
    return this.dashboardLogic.clientesMora({
      diasUrgente: query.diasUrgente ?? 30,
      fechaDesde: query.fechaDesde ?? null,
      fechaHasta: query.fechaHasta ?? null,
    });
  }

  @Get('balones/bajas-solicitadas')
  @Permisos(PermisoBanderas.DASHBOARD_VER_BALONES)
  @ApiOperation({ summary: 'Solicitudes de baja de balones pendientes' })
  balonesBajasSolicitadas() {
    return this.dashboardLogic.balonesBajasSolicitadas();
  }

  @Get('garantias/alquiler')
  @Permisos(PermisoBanderas.DASHBOARD_VER_GARANTIAS)
  @ApiOperation({ summary: 'Resumen de garantías por contratos de alquiler' })
  garantiasAlquiler() {
    return this.dashboardLogic.garantiasAlquiler();
  }

  @Get('productos')
  @Permisos(PermisoBanderas.DASHBOARD_VER_PRODUCTOS)
  @ApiOperation({
    summary: 'KPIs del módulo Productos (totales, almacenes, inventario)',
  })
  kpiProductos(@Query() query: IdAlmacenQueryDto) {
    return this.dashboardLogic.kpiProductos(query.idAlmacen ?? null);
  }

  @Get('productos/stock-categoria')
  @Permisos(PermisoBanderas.DASHBOARD_VER_PRODUCTOS)
  @ApiOperation({ summary: 'Distribución de stock valorizado por categoría' })
  stockPorCategoria(@Query() query: IdAlmacenQueryDto) {
    return this.dashboardLogic.stockPorCategoria(query.idAlmacen ?? null);
  }

  @Get('productos/velocidad-salida')
  @Permisos(PermisoBanderas.DASHBOARD_VER_PRODUCTOS)
  @ApiOperation({ summary: 'Velocidad de salida (rotación) de productos' })
  velocidadSalida(@Query() query: VelocidadSalidaQueryDto) {
    return this.dashboardLogic.velocidadSalida({
      fechaDesde: query.fechaDesde ?? null,
      fechaHasta: query.fechaHasta ?? null,
      idAlmacen: query.idAlmacen ?? null,
      limite: query.limite ?? 20,
    });
  }

  @Get('productos/stock-critico')
  @Permisos(PermisoBanderas.DASHBOARD_VER_PRODUCTOS)
  @ApiOperation({
    summary: 'Productos/accesorios con stock igual o bajo el mínimo',
  })
  stockCritico(@Query() query: StockCriticoQueryDto) {
    return this.dashboardLogic.stockCritico(
      query.idAlmacen ?? null,
      query.limite ?? 10,
    );
  }
}
