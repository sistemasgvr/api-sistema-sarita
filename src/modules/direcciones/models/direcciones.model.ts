import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { CreateDireccionDto, FiltroDireccionesDto, UpdateDireccionDto } from '../dto/filtros-direcciones.dto';

@Injectable()
export class DireccionesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroDireccionesDto) {
    return this.db.callFunctionJson<AuthListResult>('cli_listar_direcciones', [
      filtros.soloActivos ?? null,
      filtros.idCliente ?? null,
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'cli_obtener_por_id_direccion',
      [id],
    );
  }

  crear(dto: CreateDireccionDto) {
    return this.db.callFunctionJson<AuthSingleResult>('cli_crear_direccion', [
      dto.idCliente?? null,
      dto.direccion?? null,
      dto.descripcion?? null,
      dto.idDepartamento?? null,
      dto.idProvincia?? null,
      dto.idDistrito?? null,
      dto.referencia?? null,
      dto.latitud?? null,
      dto.longitud?? null,
      dto.esPrincipal ?? false,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateDireccionDto) {
  return this.db.callFunctionJson<AuthSingleResult>(
    'cli_actualizar_direccion',
    [
      id,
      dto.idCliente ?? null,
      dto.direccion ?? null,
      dto.descripcion ?? null,
      dto.idPais ?? null,
      dto.idDepartamento ?? null,
      dto.idProvincia ?? null,
      dto.idDistrito ?? null,
      dto.referencia ?? null,
      dto.latitud ?? null,
      dto.longitud ?? null,
      dto.esPrincipal ?? null,
      dto.idUsuarioAuditoria ?? null,
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
