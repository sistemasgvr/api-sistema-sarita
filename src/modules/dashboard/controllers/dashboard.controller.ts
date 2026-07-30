import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { DashboardLogic } from '../logic/dashboard.logic';
import { GeneralKpiQueryDto, BalonesKpiQueryDto, ClientesKpiQueryDto, ProductosKpiQueryDto, VentasKpiQueryDto } from '../dto/dashboard.dto';
import { Public } from 'src/common/decorators/public.decorator';

@ApiTags('Dashboard')
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboardLogic: DashboardLogic) {}

  @Get('general')
  @Permisos(PermisoBanderas.DASHBOARD_VER_GENERAL)
  @ApiOperation({ summary: 'KPIs generales del Dashboard (Solicitudes, Stock Crítico)' })
  @Public()
  kpiGeneral(@Query() query: GeneralKpiQueryDto) {
    return this.dashboardLogic.kpiGeneral({
      idAlmacen: query.idAlmacen ?? null,
      limite: query.limite ?? 20,
      offset: query.offset ?? 0,
    });
  }

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
    return this.dashboardLogic.kpiBalones(query.diasAlerta ?? 30, query.idCliente ?? null);
  }

  @Get('productos')
  @Permisos(PermisoBanderas.DASHBOARD_VER_PRODUCTOS) 
  @ApiOperation({ summary: 'KPIs del módulo Analítica de Productos / Inventario' })
  @Public()
  kpiProductos(@Query() query: ProductosKpiQueryDto) {
    return this.dashboardLogic.kpiProductos({
      idAlmacen: query.idAlmacen ?? null,
      busqueda: query.busqueda ?? null,
      limite: query.limite ?? 20,
      offset: query.offset ?? 0,
    });
  }

  @Get('ventas')
  @Permisos(PermisoBanderas.DASHBOARD_VER_VENTAS) 
  @ApiOperation({ summary: 'KPIs del módulo Ventas & Facturación' })
  @Public()
  kpiVentas(@Query() query: VentasKpiQueryDto) {
    return this.dashboardLogic.kpiVentas({
      fecha: query.fecha ?? null,
      limite: query.limite ?? 20,
      offset: query.offset ?? 0,
    });
  }
}
