import { Injectable } from '@nestjs/common';
import { ClientesKpiParams, DashboardModel } from '../models/dashboard.model';

@Injectable()
export class DashboardLogic {
  constructor(private readonly dashboardModel: DashboardModel) {}


  async kpiGeneral(query: { idAlmacen?: number | null; limite?: number; offset?: number }) {
    const limite = query.limite ?? 20;
    const offset = query.offset ?? 0;

    const [numeroTotalSolicitudes, stockCritico] = await Promise.all([
      this.dashboardModel.numeroTotalSolicitudes(limite, offset),
      this.dashboardModel.stockCritico(query.idAlmacen, limite, offset),
    ]);

    return {
      numeroTotalSolicitudes,
      stockCritico,
    };
  }

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

async kpiProductos(query: { idAlmacen?: number | null; busqueda?: string | null; limite?: number; offset?: number }) {
  const limite = query.limite ?? 20;
  const offset = query.offset ?? 0;

  const [productos, almacenes, margen, valorInventario] = await Promise.all([
    this.dashboardModel.productosRegistrados(query.busqueda, limite, offset),
    this.dashboardModel.almacenesOperativos(limite, offset),
    this.dashboardModel.margenPromedio(limite, offset),
    this.dashboardModel.valorTotalInventario(query.idAlmacen, limite, offset),
  ]);

  return {
    productos,
    almacenes,
    margen,
    valorInventario,
  };
}

async kpiVentas(query: { fecha?: string | null; limite?: number; offset?: number }) {
  const limite = query.limite ?? 20;
  const offset = query.offset ?? 0;
  const fecha = query.fecha ?? null;

  const [ventasDelDia, operacionesRegistradas, montoMora, gananciasDelDia] = await Promise.all([
    this.dashboardModel.ventasDelDia(fecha, limite, offset),
    this.dashboardModel.operacionesRegistradas(fecha, limite, offset),
    this.dashboardModel.montoMora(fecha, limite, offset),
    this.dashboardModel.gananciasDelDia(fecha, limite, offset),
  ]);

  return {
    ventasDelDia,
    operacionesRegistradas,
    montoMora,
    gananciasDelDia,
  };
}
}
