import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';

export interface ClientesKpiParams {
  idCliente?: number | null;
  fechaDesde?: string | null;
  fechaHasta?: string | null;
}

@Injectable()
export class DashboardModel {
  constructor(private readonly db: DatabaseService) {}

  // ---------- General ----------

  async numeroTotalSolicitudes(limite = 20, offset = 0): Promise<unknown> {
    return this.db.callFunctionJson('dash_obtener_solicitudes_baja', [
      limite,
      offset,
    ]);
  }

  async stockCritico(idAlmacen?: number | null, limite = 20, offset = 0): Promise<unknown> {
    return this.db.callFunctionJson('dash_stock_critico', [
      idAlmacen ?? null,
      limite,
      offset,
    ]);
  }

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

  // ---------- Productos ----------

  async productosRegistrados(busqueda?: string | null, limite = 20, offset = 0): Promise<unknown> {
  return this.db.callFunctionJson('dash_productos_registrados', [
    busqueda ?? '',
    limite,
    offset,
  ]);
}

async almacenesOperativos(limite = 20, offset = 0): Promise<unknown> {
  return this.db.callFunctionJson('dash_almacenes_operativos', [
    limite,
    offset,
  ]);
}

async margenPromedio(limite = 20, offset = 0): Promise<unknown> {
  return this.db.callFunctionJson('dash_margen_promedio', [
    limite,
    offset,
  ]);
}

async valorTotalInventario(idAlmacen?: number | null, limite = 20, offset = 0): Promise<unknown> {
  return this.db.callFunctionJson('dash_valor_total_inventario', [
    idAlmacen ?? null,
    limite,
    offset,
  ]);
}

// ---------- Ventas ----------

async ventasDelDia(fecha?: string | null, limite = 20, offset = 0): Promise<unknown> {
  return this.db.callFunctionJson('dash_ventas_del_dia', [
    fecha ?? null,
    limite,
    offset,
  ]);
}

async operacionesRegistradas(fecha?: string | null, limite = 20, offset = 0): Promise<unknown> {
  return this.db.callFunctionJson('dash_operaciones_registradas', [
    fecha ?? null,
    limite,
    offset,
  ]);
}

async montoMora(fecha?: string | null, limite = 20, offset = 0): Promise<unknown> {
  return this.db.callFunctionJson('dash_monto_mora', [
    fecha ?? null,
    limite,
    offset,
  ]);
}

async gananciasDelDia(fecha?: string | null, limite = 20, offset = 0): Promise<unknown> {
  return this.db.callFunctionJson('dash_ganancias_del_dia', [
    fecha ?? null,
    limite,
    offset,
  ]);
}
}
