import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import {
  CreateDocumentoVencimientoDto,
  FiltroDocumentoVencimientoDto,
  UpdateDocumentoVencimientoDto,
} from '../dto/documentos-vencimiento.dto';

@Injectable()
export class DocumentosVencimientoModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroDocumentoVencimientoDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_documentos_vencimiento', [
      filtros.isActivos ?? null,
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.pagina ?? 1,
      filtros.idCategoria ?? null,
      filtros.idVehiculo ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_obtener_documento_vencimiento',
      [id],
    );
  }

  crear(dto: CreateDocumentoVencimientoDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_crear_documento_vencimiento',
      [
        dto.idCategoria ?? null,
        dto.descripcion,
        dto.idVehiculo ?? null,
        dto.fechaVencimiento,
        dto.fechaRenovacion ?? null,
        dto.numeroDocumento ?? null,
        dto.observacion ?? null,
        dto.idEstado ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(id: number, dto: UpdateDocumentoVencimientoDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_actualizar_documento_vencimiento',
      [
        id,
        dto.idCategoria ?? null,
        dto.descripcion ?? null,
        dto.idVehiculo ?? null,
        dto.fechaVencimiento ?? null,
        dto.fechaRenovacion ?? null,
        dto.numeroDocumento ?? null,
        dto.observacion ?? null,
        dto.idEstado ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_documento_vencimiento', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
