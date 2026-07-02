import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroSubCategoriasProductoDto } from '../dto/sub-categorias-producto.dto';

@Injectable()
export class SubCategoriasProductoModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroSubCategoriasProductoDto) {
    return this.db.callFunctionJson<AuthListResult>('pro_listar_sub_categorias', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idCategoria ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_sub_categoria', [id]);
  }

  crear(
    idCategoria: number,
    nombre: string,
    descripcion: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_sub_categoria', [
      idCategoria,
      nombre,
      descripcion,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    idCategoria: number | null,
    nombre: string | null,
    descripcion: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_actualizar_sub_categoria', [
      id,
      idCategoria,
      nombre,
      descripcion,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_sub_categoria', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
