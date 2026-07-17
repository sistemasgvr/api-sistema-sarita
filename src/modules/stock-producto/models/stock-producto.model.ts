import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroStockDto } from '../dto/stock-producto.dto';

@Injectable()
export class StockProductoModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroStockDto) {
    return this.db.callFunctionJson<AuthListResult>('pro_listar_stock', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idAlmacen ?? null,
      filtros.idProducto ?? null,
      filtros.soloBajoMinimo ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_stock', [id]);
  }

  crear(
    idAlmacen: number,
    idProducto: number,
    stock: number,
    stockMinimo: number,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_stock', [
      idAlmacen,
      idProducto,
      stock,
      stockMinimo,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    stock: number | null,
    stockMinimo: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_actualizar_stock', [
      id,
      stock,
      stockMinimo,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_stock', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
