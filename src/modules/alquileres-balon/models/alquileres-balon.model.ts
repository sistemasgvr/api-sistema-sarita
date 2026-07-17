import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateAlquileresBalonDto,
  FiltroAlquileresBalonDto,
  UpdateAlquileresBalonDto,
} from '../dto/alquileres-balon.dto';

@Injectable()
export class AlquileresBalonModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroAlquileresBalonDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_alquileres', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idCliente ?? null,
      filtros.idAlmacen ?? null,
      filtros.idEstado ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_alquiler', [id]);
  }

  crear(dto: CreateAlquileresBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_alquiler', [
      dto.numeroAlquiler ?? null,
      dto.idCliente ?? null,
      dto.idAlmacen ?? null,
      dto.fechaInicio ?? null,
      dto.fechaFinPactada ?? null,
      dto.fechaFinReal ?? null,
      dto.tarifaDiaria ?? null,
      dto.totalCobrado ?? null,
      dto.idEstado ?? null,
      dto.observacion ?? null,
      dto.idComprobanteVenta ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateAlquileresBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_actualizar_alquiler', [
      id,
      dto.numeroAlquiler ?? null,
      dto.idCliente ?? null,
      dto.idAlmacen ?? null,
      dto.fechaInicio ?? null,
      dto.fechaFinPactada ?? null,
      dto.fechaFinReal ?? null,
      dto.tarifaDiaria ?? null,
      dto.totalCobrado ?? null,
      dto.idEstado ?? null,
      dto.observacion ?? null,
      dto.idComprobanteVenta ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_alquiler', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
