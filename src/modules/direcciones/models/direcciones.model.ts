import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroDireccionesDto } from '../dto/filtros-direcciones.dto';

@Injectable()
export class DireccionesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroDireccionesDto) {
    return this.db.callFunctionJson<AuthListResult>('cli_listar_direcciones', [
      filtros.soloActivos ?? null,
      filtros.idCliente ?? null,
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.pagina ?? 1,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'cli_obtener_por_id_direccion',
      [id],
    );
  }

  crear(
    idCliente: number,
    direccion: string,
    descripcion: string | null,
    idDepartamento: number | null,
    idProvincia: number | null,
    idDistrito: number | null,
    referencia: string | null,
    esPrincipal: boolean | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('cli_crear_direccion', [
      idCliente,
      direccion,
      descripcion,
      idDepartamento,
      idProvincia,
      idDistrito,
      referencia,
      esPrincipal ?? false,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
  id: number,
  idCliente: number | null,
  direccion: string | null,
  descripcion: string | null,
  idPais: number | null,
  idDepartamento: number | null,
  idProvincia: number | null,
  idDistrito: number | null,
  referencia: string | null,
  esPrincipal: boolean | null,
  idUsuarioAuditoria?: number,
) {
  return this.db.callFunctionJson<AuthSingleResult>(
    'cli_actualizar_direccion',
    [
      id,
      idCliente,
      direccion,
      descripcion,
      idPais,
      idDepartamento,
      idProvincia,
      idDistrito,
      referencia,
      esPrincipal,
      idUsuarioAuditoria ?? null,
    ],
  );
}

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>(
      'cli_eliminar_direccion',
      [id, idUsuarioAuditoria ?? null],
    );
  }
}
