import { Injectable } from '@nestjs/common';
import { ClientesKpiParams, DashboardModel } from '../models/dashboard.model';

@Injectable()
export class DashboardLogic {
  constructor(private readonly dashboardModel: DashboardModel) {}

  async kpiClientes(params: ClientesKpiParams = {}) {
    const [totalClientes, clientesConDeuda] = await Promise.all([
      this.dashboardModel.totalClientes(params),
      this.dashboardModel.clientesConDeuda(params),
    ]);

    return {
      totalClientes,
      clientesConDeuda,
    };
  }

  async kpiBalones(diasAlerta = 30, idCliente?: number | null) {
    const [
      totalBalones,
      enAlmacen,
      prestados,
      alquilados,
      mantenimiento,
      phPorVencer,
    ] = await Promise.all([
      this.dashboardModel.totalBalones(idCliente),
      this.dashboardModel.balonesEnAlmacen(idCliente),
      this.dashboardModel.balonesPrestados(idCliente),
      this.dashboardModel.balonesAlquilados(idCliente),
      this.dashboardModel.balonesMantenimiento(idCliente),
      this.dashboardModel.balonesPhPorVencer(diasAlerta, idCliente),
    ]);

    return {
      totalBalones,
      enAlmacen,
      prestados,
      alquilados,
      mantenimiento,
      phPorVencer,
    };
  }
}
