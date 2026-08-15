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
  SolicitarReactivacionClienteDto,
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
      filtros.idTipoSolicitud ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_obtener_baja_cliente',
      [id],
    );
  }

  async resolverIdTipoSolicitud(nombreOpcion: string) {
    const result = await this.db.query<{ id: number }>(
      `SELECT lo.id
       FROM gen_lista_opciones lo
       INNER JOIN gen_lista l ON lo.id_lista = l.id
       WHERE LOWER(l.nombre) = LOWER('TipoSolicitud')
         AND UPPER(TRIM(lo.nombre)) = UPPER($1)
         AND lo.estado = 1
       LIMIT 1`,
      [nombreOpcion],
    );
    return result.rows[0]?.id ?? null;
  }

  solicitarReactivacion(dto: SolicitarReactivacionClienteDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_solicitar_reactivacion_cliente',
      [
        dto.idCliente,
        dto.motivoDetalle ?? null,
        dto.idUsuarioAuditoria ?? null,
        dto.idTipoSolicitud ?? null,
      ],
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
        dto.idTipoSolicitud ?? null,
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
