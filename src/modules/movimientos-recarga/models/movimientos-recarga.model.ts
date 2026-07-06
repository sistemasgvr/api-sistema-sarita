import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateMovimientosRecargaDto,
  FiltroMovimientosRecargaDto,
  UpdateMovimientosRecargaDto,
} from '../dto/movimientos-recarga.dto';

@Injectable()
export class MovimientosRecargaModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroMovimientosRecargaDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_movimientos_recarga', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idBalon ?? null,
      filtros.idAlmacen ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_movimiento_recarga', [id]);
  }

  crear(dto: CreateMovimientosRecargaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_movimiento_recarga', [
      dto.fechaSalidaAlmacen ?? null,
      dto.idBalon ?? null,
      dto.idProducto ?? null,
      dto.capacidad ?? null,
      dto.idUnidadMedida ?? null,
      dto.serieGuiaSalida ?? null,
      dto.numeroGuiaSalida ?? null,
      dto.serieGuiaIngreso ?? null,
      dto.numeroGuiaIngreso ?? null,
      dto.serieFactura ?? null,
      dto.numeroFactura ?? null,
      dto.idComprobante ?? null,
      dto.fechaLlegadaAlmacen ?? null,
      dto.lote ?? null,
      dto.fechaVencimientoLote ?? null,
      dto.fechaPruebaHidrostatica ?? null,
      dto.idProveedor ?? null,
      dto.observacion ?? null,
      dto.idAlmacen ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateMovimientosRecargaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_actualizar_movimiento_recarga', [
      id,
      dto.fechaSalidaAlmacen ?? null,
      dto.idProducto ?? null,
      dto.capacidad ?? null,
      dto.idUnidadMedida ?? null,
      dto.serieGuiaSalida ?? null,
      dto.numeroGuiaSalida ?? null,
      dto.serieGuiaIngreso ?? null,
      dto.numeroGuiaIngreso ?? null,
      dto.serieFactura ?? null,
      dto.numeroFactura ?? null,
      dto.idComprobante ?? null,
      dto.fechaLlegadaAlmacen ?? null,
      dto.lote ?? null,
      dto.fechaVencimientoLote ?? null,
      dto.fechaPruebaHidrostatica ?? null,
      dto.idProveedor ?? null,
      dto.observacion ?? null,
      dto.idAlmacen ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_movimiento_recarga', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
