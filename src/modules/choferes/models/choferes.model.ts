import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import {
  CreateChoferDto,
  FiltroChoferDto,
  UpdateChoferDto,
} from '../dto/choferes.dto';

@Injectable()
export class ChoferesModel {
  constructor(private readonly db: DatabaseService) { }

  listar(filtros: FiltroChoferDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_choferes', [
      filtros.isActivos ?? null,
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.idCliente ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_obtener_chofer',
      [id],
    );
  }

  crear(dto: CreateChoferDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_crear_chofer',
      [
        dto.nombres,
        dto.idCliente ?? null,
        dto.apellidoPaterno ?? null,
        dto.apellidoMaterno ?? null,
        dto.idTipoDocumento ?? null,
        dto.numeroDocumento ?? null,
        dto.telefono ?? null,
        dto.codigoLicencia ?? null,
        dto.fechaEmision ?? null,
        dto.fechaVencimiento ?? null,
        dto.idTipoLicencia ?? null,
        dto.idCategoriaLicencia ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(id: number, dto: UpdateChoferDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_actualizar_chofer',
      [
        id,
        dto.idCliente ?? null,
        dto.apellidoPaterno ?? null,
        dto.apellidoMaterno ?? null,
        dto.nombres ?? null,
        dto.idTipoDocumento ?? null,
        dto.numeroDocumento ?? null,
        dto.telefono ?? null,
        dto.codigoLicencia ?? null,
        dto.fechaEmision ?? null,
        dto.fechaVencimiento ?? null,
        dto.idTipoLicencia ?? null,
        dto.idCategoriaLicencia ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_chofer', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
