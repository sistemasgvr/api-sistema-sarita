import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import {
  CreateLicenciaDto,
  FiltroLicenciaDto,
  UpdateLicenciaDto,
} from '../dto/licencias.dto';

@Injectable()
export class LicenciasModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroLicenciaDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_licencias', [
      filtros.soloActivos ?? null,
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.idChofer ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_obtener_licencia',
      [id],
    );
  }

  crear(dto: CreateLicenciaDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_crear_licencia',
      [
        dto.codigo,
        dto.idChofer,
        dto.fechaEmision,
        dto.fechaVencimiento,
        dto.idTipoLicencia ?? null,
        dto.idCategoriaLicencia ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(id: number, dto: UpdateLicenciaDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_actualizar_licencia',
      [
        id,
        dto.idChofer ?? null,
        dto.codigo ?? null,
        dto.idTipoLicencia ?? null,
        dto.idCategoriaLicencia ?? null,
        dto.fechaEmision ?? null,
        dto.fechaVencimiento ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_licencia', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
