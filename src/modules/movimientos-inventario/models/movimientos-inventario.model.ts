import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroMovimientosInventarioDto } from '../dto/movimientos-inventario.dto';

@Injectable()
export class MovimientosInventarioModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroMovimientosInventarioDto) {
    return this.db.callFunctionJson<AuthListResult>('pro_listar_movimientos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idProducto ?? null,
      filtros.idAlmacen ?? null,
      filtros.idTipoMovimiento ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_movimiento', [id]);
  }

  crear(
    fecha: string,
    idProducto: number,
    idAlmacen: number,
    idTipoMovimiento: number,
    cantidad: number,
    idDocumentoRef: number | null,
    idTipoDocumentoRef: number | null,
    glosa: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_movimiento', [
      fecha,
      idProducto,
      idAlmacen,
      idTipoMovimiento,
      cantidad,
      idDocumentoRef,
      idTipoDocumentoRef,
      glosa,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    fecha: string | null,
    glosa: string | null,
    idDocumentoRef: number | null,
    idTipoDocumentoRef: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_actualizar_movimiento', [
      id,
      fecha,
      glosa,
      idDocumentoRef,
      idTipoDocumentoRef,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_movimiento', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
