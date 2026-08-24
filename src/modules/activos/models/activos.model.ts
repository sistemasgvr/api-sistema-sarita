import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import {
  CreateActivoDto,
  FiltroActivoDto,
  UpdateActivoDto,
} from '../dto/activos.dto';

@Injectable()
export class ActivosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroActivoDto) {
    return this.db.callFunctionJson<AuthListResult>('act_listar_activos', [
      filtros.estado ?? null,
      filtros.idTipo ?? null,
      filtros.idSucursal ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.importeMin ?? null,
      filtros.importeMax ?? null,
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>('act_obtener_activo', [id]);
  }

  crear(dto: CreateActivoDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>('act_crear_activo', [
      dto.idTipo ?? null,
      dto.descripcion ?? null,
      dto.fechaCompra ?? null,
      dto.importe ?? null,
      dto.idSucursal ?? null,
      dto.marca ?? null,
      dto.modelo ?? null,
      dto.numeroSerie ?? null,
      dto.idTrabajadorResponsable ?? null,
      dto.imagenPrincipalRuta ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateActivoDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>('act_actualizar_activo', [
      id,
      dto.idTipo ?? null,
      dto.descripcion ?? null,
      dto.fechaCompra ?? null,
      dto.importe ?? null,
      dto.idSucursal ?? null,
      dto.marca ?? null,
      dto.modelo ?? null,
      dto.numeroSerie ?? null,
      dto.idTrabajadorResponsable ?? null,
      dto.imagenPrincipalRuta ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('act_eliminar_activo', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
