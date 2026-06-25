import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

@Injectable()
export class RolesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroPaginacionDto) {
    return this.db.callFunctionJson<AuthListResult>('auth_listar_roles', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_obtener_rol', [id]);
  }

  crear(nombre: string, descripcion: string | null, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_crear_rol', [
      nombre,
      descripcion,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    nombre: string | null,
    descripcion: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_actualizar_rol', [
      id,
      nombre,
      descripcion,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('auth_eliminar_rol', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
