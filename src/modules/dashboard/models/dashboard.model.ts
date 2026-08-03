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
}
