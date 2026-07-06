import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateTiposBalonDto,
  FiltroTiposBalonDto,
  UpdateTiposBalonDto,
} from '../dto/tipos-balon.dto';

@Injectable()
export class TiposBalonModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroTiposBalonDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_tipos_balon', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idGas ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_tipo_balon', [id]);
  }

  crear(dto: CreateTiposBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_tipo_balon', [
      dto.nombre ?? null,
      dto.idGas ?? null,
      dto.capacidad ?? null,
      dto.idUnidadMedida ?? null,
      dto.peso ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateTiposBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_actualizar_tipo_balon', [
      id,
      dto.nombre ?? null,
      dto.idGas ?? null,
      dto.capacidad ?? null,
      dto.idUnidadMedida ?? null,
      dto.peso ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_tipo_balon', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
