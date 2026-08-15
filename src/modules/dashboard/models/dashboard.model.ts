import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';

export interface ClientesKpiParams {
  idCliente?: number | null;
  fechaDesde?: string | null;
  fechaHasta?: string | null;
}

export interface RangoFechasParams {
  fechaDesde?: string | null;
  fechaHasta?: string | null;
}

export interface VentasNetasParams extends RangoFechasParams {
  idCliente?: number | null;
}

export interface DeudaKpiParams extends RangoFechasParams {
  idCliente?: number | null;
}

export interface TopClientesVentaParams extends RangoFechasParams {
  limite?: number;
}

export interface ClientesMoraParams extends RangoFechasParams {
  diasUrgente?: number;
}

export interface VelocidadSalidaParams extends RangoFechasParams {
  idAlmacen?: number | null;
  limite?: number;
}

@Injectable()
export class DashboardModel {
  constructor(private readonly db: DatabaseService) {}

  // ---------- Clientes ----------

  async totalClientes(params: ClientesKpiParams = {}): Promise<number> {
    return this.db.callFunctionJson<number>('dash_total_clientes', [
      params.idCliente ?? null,
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
    ]);
  }

  async clientesConDeuda(params: ClientesKpiParams = {}): Promise<unknown> {
    return this.db.callFunctionJson('dash_clientes_con_deuda', [
      params.idCliente ?? null,
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
    ]);
  }

  // ---------- Balones ----------

  async totalBalones(idCliente?: number | null): Promise<number> {
    return this.db.callFunctionJson<number>('dash_total_balones', [
      idCliente ?? null,
    ]);
  }

  async balonesEnAlmacen(idCliente?: number | null): Promise<unknown> {
    return this.db.callFunctionJson('dash_balones_en_almacen', [
      idCliente ?? null,
    ]);
  }

  async balonesPrestados(idCliente?: number | null): Promise<unknown> {
    return this.db.callFunctionJson('dash_balones_prestados', [
      idCliente ?? null,
    ]);
  }

  async balonesAlquilados(idCliente?: number | null): Promise<unknown> {
    return this.db.callFunctionJson('dash_balones_alquilados', [
      idCliente ?? null,
    ]);
  }

  async balonesMantenimiento(idCliente?: number | null): Promise<unknown> {
    return this.db.callFunctionJson('dash_balones_mantenimiento', [
      idCliente ?? null,
    ]);
  }

  async balonesPhPorVencer(
    diasAlerta: number,
    idCliente?: number | null,
  ): Promise<unknown> {
    return this.db.callFunctionJson('dash_balones_ph_por_vencer', [
      diasAlerta,
      idCliente ?? null,
    ]);
  }

  // ---------- Ventas / Compras ----------

  async ventasNetas(params: VentasNetasParams = {}): Promise<number> {
    return this.db.callFunctionJson<number>('dash_ventas_netas', [
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
      params.idCliente ?? null,
    ]);
  }

  async comprasNetas(params: RangoFechasParams = {}): Promise<number> {
    return this.db.callFunctionJson<number>('dash_compras_netas', [
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
    ]);
  }

  async deudaCuentas(tipo: 'COBRAR' | 'PAGAR', params: DeudaKpiParams = {}) {
    return this.db.callFunctionJson('dash_deuda_cuentas', [
      tipo,
      params.idCliente ?? null,
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
    ]);
  }

  async creditosOtorgados(params: RangoFechasParams = {}): Promise<number> {
    return this.db.callFunctionJson<number>('dash_creditos_otorgados', [
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
    ]);
  }

  async clientesMora(params: ClientesMoraParams = {}): Promise<unknown> {
    return this.db.callFunctionJson('dash_clientes_mora', [
      params.diasUrgente ?? 30,
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
    ]);
  }

  // ---------- Histórico / comparativos ----------

  async historicoVentasCompras(anio?: number | null): Promise<unknown> {
    return this.db.callFunctionJson('dash_historico_ventas_compras', [
      anio ?? null,
    ]);
  }

  async topClientesVenta(
    params: TopClientesVentaParams = {},
  ): Promise<unknown> {
    return this.db.callFunctionJson('dash_top_clientes_venta', [
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
      params.limite ?? 10,
    ]);
  }

  async demandaGases(params: RangoFechasParams = {}): Promise<unknown> {
    return this.db.callFunctionJson('dash_demanda_gases', [
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
    ]);
  }

  async ventaGasesComparativo(
    anio?: number | null,
    mes?: number | null,
  ): Promise<unknown> {
    return this.db.callFunctionJson('dash_venta_gases_comparativo', [
      anio ?? null,
      mes ?? null,
    ]);
  }

  // ---------- Bajas de balones ----------

  async balonesBajasSolicitadas(): Promise<unknown> {
    return this.db.callFunctionJson('dash_balones_bajas_solicitadas', []);
  }

  // ---------- Garantías por alquiler ----------

  async garantiasAlquiler(): Promise<unknown> {
    return this.db.callFunctionJson('dash_garantias_alquiler', []);
  }

  // ---------- Productos / Inventario ----------

  async totalProductos(): Promise<{
    total: number;
    accesorios: number;
    gases: number;
    servicios: number;
  }> {
    const data = await this.db.callFunctionJson<{
      resumen: {
        total: number;
        accesorios: number;
        gases: number;
        servicios: number;
      };
    }>('pro_listar_productos', ['', 1, 0]);
    return data?.resumen ?? { total: 0, accesorios: 0, gases: 0, servicios: 0 };
  }

  async totalAlmacenes(): Promise<number> {
    const data = await this.db.callFunctionJson<{ total: number }>(
      'gen_listar_almacenes',
      ['', 1, 0],
    );
    return data?.total ?? 0;
  }

  async inventarioResumen(idAlmacen?: number | null): Promise<unknown> {
    return this.db.callFunctionJson('dash_inventario_resumen', [
      idAlmacen ?? null,
    ]);
  }

  async stockPorCategoria(idAlmacen?: number | null): Promise<unknown> {
    return this.db.callFunctionJson('dash_stock_por_categoria', [
      idAlmacen ?? null,
    ]);
  }

  async velocidadSalida(params: VelocidadSalidaParams = {}): Promise<unknown> {
    return this.db.callFunctionJson('dash_velocidad_salida', [
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
      params.idAlmacen ?? null,
      params.limite ?? 20,
    ]);
  }

  async stockCritico(idAlmacen?: number | null, limite = 10): Promise<unknown> {
    return this.db.callFunctionJson('pro_listar_stock', [
      '',
      limite,
      0,
      idAlmacen ?? null,
      null,
      true,
      1,
    ]);
  }
}
