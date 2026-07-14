import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { FiltroClienteDto } from '../dto/filtros-cliente.dto';
import {
  AuthDeleteResult,
  AuthExisteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { CreateClienteDto, UpdateClienteDto } from '../dto/crear-cliente.dto';

@Injectable()
export class ClientesModel {
  constructor(private readonly db: DatabaseService) { }

  listar(filtros: FiltroClienteDto) {
    return this.db.callFunctionJson<AuthListResult>('cli_listar_clientes', [
      filtros.soloActivos ?? null,
      filtros.idTipoCliente ?? null,
      filtros.buscar ?? null,
      filtros.limite ?? 10,
      filtros.pagina ?? 1,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_obtener_por_id_cliente',
      [id],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>(
      'cli_eliminar_logico_cliente',
      [id, idUsuarioAuditoria ?? null],
    );
  }

  restaurar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('cli_restaurar_cliente', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  validarDocumento(numeroDocumento: string, idExcluir?: number) {
    return this.db.callFunctionJson<AuthExisteResult>(
      'cli_validar_documento_cliente',
      [numeroDocumento, idExcluir ?? null],
    );
  }

  crear(dto: CreateClienteDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_crear_clientes',
      [
        dto.codigoInterno ?? null,
        dto.razonSocial ?? null,
        dto.idTipoCliente ?? null,
        dto.idTipoPersona ?? null,
        dto.nombres ?? null,
        dto.apellidoPaterno ?? null,
        dto.apellidoMaterno ?? null,
        dto.idTipoDocumento ?? null,
        dto.numeroDocumento ?? null,
        dto.telefono ?? null,
        dto.email ?? null,
        dto.esAgentePercepcion ?? false,
        dto.esBuenContribuyente ?? false,
        dto.esAgenteRetenedor ?? false,
        dto.afectoRus ?? false,
        dto.situacionSunat ?? null,
        dto.estadoContribuyenteSunat ?? null,
        dto.observacion ?? null,
        dto.direccion ?? null,
        dto.referencia ?? null,
        dto.latitud ?? null, 
        dto.longitud ?? null,
        dto.idDepartamento ?? null,
        dto.idProvincia ?? null,
        dto.idDistrito ?? null,
        dto.idPais ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(id: number, dto: UpdateClienteDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_actualizar_por_id_cliente',
      [
        id,
        dto.codigoInterno ?? null,
        dto.razonSocial ?? null,
        dto.idTipoCliente ?? null,
        dto.idTipoPersona ?? null,
        dto.nombres ?? null,
        dto.apellidoPaterno ?? null,
        dto.apellidoMaterno ?? null,
        dto.idTipoDocumento ?? null,
        dto.numeroDocumento ?? null,
        dto.telefono ?? null,
        dto.email ?? null,
        dto.esAgentePercepcion ?? null,
        dto.esBuenContribuyente ?? null,
        dto.esAgenteRetenedor ?? null,
        dto.afectoRus ?? null,
        dto.situacionSunat ?? null,
        dto.estadoContribuyenteSunat ?? null,
        dto.observacion ?? null,
        dto.direccion ?? null,
        dto.referencia ?? null,
        dto.latitud ?? null, 
        dto.longitud ?? null,
        dto.idDepartamento ?? null,
        dto.idProvincia ?? null,
        dto.idDistrito ?? null,
        dto.idPais ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }
}
