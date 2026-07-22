import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateAlquileresDetalleDto,
  DevolverAlquileresDetalleDto,
  FiltroAlquileresDetalleDto,
  UpdateAlquileresDetalleDto,
} from '../dto/alquileres-detalle.dto';

@Injectable()
export class AlquileresDetalleModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroAlquileresDetalleDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_alquiler_detalles', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idAlquiler ?? null,
      filtros.idBalon ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_alquiler_detalle', [id]);
  }

  crear(dto: CreateAlquileresDetalleDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_alquiler_detalle', [
      dto.idAlquiler ?? null,
      dto.idBalon ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateAlquileresDetalleDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_actualizar_alquiler_detalle', [
      id,
      dto.idBalon ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  devolver(id: number, dto: DevolverAlquileresDetalleDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_devolver_alquiler_detalle', [
      id,
      dto.fechaDevolucion ?? null,
      dto.idAlmacenDestino ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_alquiler_detalle', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
