import { Injectable } from '@nestjs/common';
import {
  ClientesKpiParams,
  ClientesMoraParams,
  DashboardModel,
  DeudaKpiParams,
  RangoFechasParams,
  TopClientesVentaParams,
  VelocidadSalidaParams,
  VentasNetasParams,
} from '../models/dashboard.model';

interface BalonDetalleFecha {
  fechaVencimiento?: string | null;
  fechaFinPactada?: string | null;
}

interface BalonesGrupo {
  cantidad?: number;
  detalle?: BalonDetalleFecha[];
}

function esRetrasoCritico(item: BalonDetalleFecha): boolean {
  const fecha = item.fechaVencimiento ?? item.fechaFinPactada;
  if (!fecha) return false;
  const hoy = new Date().toISOString().slice(0, 10);
  const fechaStr = String(fecha).slice(0, 10);
  return fechaStr < hoy;
}

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

    // Balance de envases en campo = préstamos + alquileres activos.
    const grupoPrestados = (prestados ?? {}) as BalonesGrupo;
    const grupoAlquilados = (alquilados ?? {}) as BalonesGrupo;
    const enCampo =
      (grupoPrestados.cantidad ?? 0) + (grupoAlquilados.cantidad ?? 0);
    const retrasoCritico =
      (grupoPrestados.detalle ?? []).filter(esRetrasoCritico).length +
      (grupoAlquilados.detalle ?? []).filter(esRetrasoCritico).length;

    return {
      totalBalones,
      enAlmacen,
      prestados,
      alquilados,
      mantenimiento,
      phPorVencer,
      envasesEnCampo: {
        cantidad: enCampo,
        retrasoCritico,
      },
    };
  }

  async kpiVentas(params: VentasNetasParams = {}) {
    const totalVentasNetas = await this.dashboardModel.ventasNetas({
      fechaDesde: params.fechaDesde ?? null,
      fechaHasta: params.fechaHasta ?? null,
      idCliente: params.idCliente ?? null,
    });

    return {
      totalVentasNetas,
    };
  }

  async kpiCompras(params: RangoFechasParams = {}) {
    const totalComprasNetas = await this.dashboardModel.comprasNetas({
      fechaDesde: params.fechaDesde ?? null,
      fechaHasta: params.fechaHasta ?? null,
    });

    return {
      totalComprasNetas,
    };
  }

  async kpiDeuda(tipo: 'COBRAR' | 'PAGAR', params: DeudaKpiParams = {}) {
    const resumen = (await this.dashboardModel.deudaCuentas(tipo, {
      idCliente: params.idCliente ?? null,
      fechaDesde: params.fechaDesde ?? null,
      fechaHasta: params.fechaHasta ?? null,
    })) as Record<string, number> | null;

    if (!resumen || tipo !== 'COBRAR') {
      return resumen;
    }

    // Eficiencia de cobranza = cobrado / (cobrado + pendiente) del periodo.
    const totalCobrado = resumen.totalCobrado ?? 0;
    const totalPendiente = resumen.totalPendiente ?? 0;
    const base = totalCobrado + totalPendiente;
    const eficienciaCobranza =
      base > 0 ? Math.round((totalCobrado / base) * 10000) / 100 : 0;

    return { ...resumen, eficienciaCobranza };
  }

  async kpiRentabilidad(params: RangoFechasParams = {}) {
    const [ventasNetas, comprasNetas] = await Promise.all([
      this.dashboardModel.ventasNetas({
        fechaDesde: params.fechaDesde ?? null,
        fechaHasta: params.fechaHasta ?? null,
      }),
      this.dashboardModel.comprasNetas({
        fechaDesde: params.fechaDesde ?? null,
        fechaHasta: params.fechaHasta ?? null,
      }),
    ]);

    return {
      ventasNetas,
      comprasNetas,
      rentabilidad: Math.round((ventasNetas - comprasNetas) * 100) / 100,
    };
  }

  async historicoVentasCompras(anio?: number | null) {
    return this.dashboardModel.historicoVentasCompras(anio ?? null);
  }

  async topClientesVenta(params: TopClientesVentaParams = {}) {
    return this.dashboardModel.topClientesVenta(params);
  }

  async demandaGases(params: RangoFechasParams = {}) {
    return this.dashboardModel.demandaGases(params);
  }

  async ventaGasesComparativo(anio?: number | null, mes?: number | null) {
    return this.dashboardModel.ventaGasesComparativo(anio ?? null, mes ?? null);
  }

  async creditosOtorgados(params: RangoFechasParams = {}) {
    return this.dashboardModel.creditosOtorgados(params);
  }

  async clientesMora(params: ClientesMoraParams = {}) {
    return this.dashboardModel.clientesMora(params);
  }

  async balonesBajasSolicitadas() {
    return this.dashboardModel.balonesBajasSolicitadas();
  }

  async garantiasAlquiler() {
    const [garantias, totalBalones, prestados, alquilados] = await Promise.all([
      this.dashboardModel.garantiasAlquiler(),
      this.dashboardModel.totalBalones(),
      this.dashboardModel.balonesPrestados(),
      this.dashboardModel.balonesAlquilados(),
    ]);

    const grupoPrestados = (prestados ?? {}) as BalonesGrupo;
    const grupoAlquilados = (alquilados ?? {}) as BalonesGrupo;
    const balonesEnCampo =
      (grupoPrestados.cantidad ?? 0) + (grupoAlquilados.cantidad ?? 0);
    const total = totalBalones ?? 0;
    const porcentajeBalonesEnCampo =
      total > 0 ? Math.round((balonesEnCampo / total) * 10000) / 100 : 0;

    return {
      ...(garantias as Record<string, unknown>),
      balonesEnCampo,
      totalBalones: total,
      porcentajeBalonesEnCampo,
    };
  }

  async kpiProductos(idAlmacen?: number | null) {
    const [totalProductos, totalAlmacenes, inventarioResumen] =
      await Promise.all([
        this.dashboardModel.totalProductos(),
        this.dashboardModel.totalAlmacenes(),
        this.dashboardModel.inventarioResumen(idAlmacen ?? null),
      ]);

    return {
      totalProductos,
      totalAlmacenes,
      ...(inventarioResumen as Record<string, unknown>),
    };
  }

  async stockPorCategoria(idAlmacen?: number | null) {
    return this.dashboardModel.stockPorCategoria(idAlmacen ?? null);
  }

  async velocidadSalida(params: VelocidadSalidaParams = {}) {
    return this.dashboardModel.velocidadSalida(params);
  }

  async stockCritico(idAlmacen?: number | null, limite = 10) {
    return this.dashboardModel.stockCritico(idAlmacen ?? null, limite);
  }
}
