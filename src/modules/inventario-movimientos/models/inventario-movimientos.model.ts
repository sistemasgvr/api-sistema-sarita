import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateInventarioMovimientoDto,
  CreateTrasladoLoteInventarioDto,
  FiltroInventarioMovimientosDto,
} from '../dto/inventario-movimientos.dto';

@Injectable()
export class InventarioMovimientosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroInventarioMovimientosDto) {
    return this.db.callFunctionJson<AuthListResult>('inv_listar_movimientos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.naturaleza ?? null,
      filtros.idProducto ?? null,
      filtros.idBalon ?? null,
      filtros.idAlmacen ?? null,
      filtros.idTipoMovimiento ?? null,
      filtros.idTipoDocumentoOrigen ?? null,
      filtros.idDocumentoOrigen ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('inv_obtener_movimiento', [id]);
  }

  crear(dto: CreateInventarioMovimientoDto) {
    return this.db.callFunctionJson<AuthSingleResult & { creado?: boolean }>(
      'inv_registrar_movimiento',
      [
        dto.naturaleza,
        dto.codigoTipoMovimiento,
        dto.fecha ?? null,
        dto.idProducto ?? null,
        dto.idBalon ?? null,
        dto.cantidad,
        dto.idAlmacenOrigen ?? null,
        dto.idAlmacenDestino ?? null,
        dto.idCliente ?? null,
        dto.codigoTipoDocumentoOrigen ?? null,
        dto.idDocumentoOrigen ?? null,
        dto.glosa ?? null,
        dto.idUsuarioAuditoria ?? null,
        null,
        dto.sentidoAjuste ?? null,
        false,
        dto.idDocumentoDetalle ?? null,
      ],
    );
  }

  crearTrasladoLote(dto: CreateTrasladoLoteInventarioDto) {
    return this.db.callFunctionJson<{
      error?: string | null;
      registros: unknown[] | null;
      total?: number;
    }>('pro_crear_traslado_lote', [
      dto.fecha,
      dto.idAlmacen,
      dto.idAlmacenDestino,
      JSON.stringify(
        dto.detalles.map((d) => ({
          idProducto: d.idProducto,
          cantidad: d.cantidad,
        })),
      ),
      dto.glosa ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.idDocumentoRef ?? null,
      dto.codigoDocumentoRef ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('inv_eliminar_movimiento', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
