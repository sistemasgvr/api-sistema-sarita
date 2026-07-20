import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import {
  FiltroBajaClienteDto,
  SolicitarBajaClienteDto,
} from '../dto/bajas-cliente.dto';

@Injectable()
export class BajasClienteModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroBajaClienteDto) {
    return this.db.callFunctionJson<AuthListResult>('cli_listar_bajas_cliente', [
      filtros.isActivos ?? null,
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.idCliente ?? null,
      filtros.idEstadoAprobacion ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_obtener_baja_cliente',
      [id],
    );
  }

  solicitar(dto: SolicitarBajaClienteDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_solicitar_baja_cliente',
      [
        dto.idCliente,
        dto.idMotivoBaja ?? null,
        dto.motivoDetalle ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  aprobar(idBaja: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_aprobar_baja_cliente',
      [idBaja, idUsuarioAuditoria ?? null],
    );
  }

  rechazar(idBaja: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_rechazar_baja_cliente',
      [idBaja, idUsuarioAuditoria ?? null],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('cli_eliminar_baja_cliente', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
