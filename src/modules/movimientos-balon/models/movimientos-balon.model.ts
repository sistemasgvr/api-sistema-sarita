import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateMovimientosBalonDto,
  FiltroMovimientosBalonDto,
  UpdateMovimientosBalonDto,
} from '../dto/movimientos-balon.dto';

@Injectable()
export class MovimientosBalonModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroMovimientosBalonDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_movimientos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idBalon ?? null,
      filtros.idTipoMovimiento ?? null,
      filtros.idCliente ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_movimiento', [id]);
  }

  crear(dto: CreateMovimientosBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_movimiento', [
      dto.idBalon ?? null,
      dto.idTipoMovimiento ?? null,
      dto.idDocumentoRef ?? null,
      dto.idTipoDocumentoRef ?? null,
      dto.idCliente ?? null,
      dto.idAlmacenOrigen ?? null,
      dto.idAlmacenDestino ?? null,
      dto.fechaMovimiento ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateMovimientosBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_actualizar_movimiento', [
      id,
      dto.idTipoMovimiento ?? null,
      dto.idDocumentoRef ?? null,
      dto.idTipoDocumentoRef ?? null,
      dto.idCliente ?? null,
      dto.idAlmacenOrigen ?? null,
      dto.idAlmacenDestino ?? null,
      dto.fechaMovimiento ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_movimiento', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
