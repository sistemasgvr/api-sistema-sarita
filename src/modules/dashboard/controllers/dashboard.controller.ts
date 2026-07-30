import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { DashboardLogic } from '../logic/dashboard.logic';
import { BalonesKpiQueryDto, ClientesKpiQueryDto } from '../dto/dashboard.dto';

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
    return this.dashboardLogic.kpiBalones(query.diasAlerta ?? 30, query.idCliente ?? null);
  }
}
