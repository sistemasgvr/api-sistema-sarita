import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroCategoriasProductoDto } from '../dto/categorias-producto.dto';

@Injectable()
export class CategoriasProductoModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroCategoriasProductoDto) {
    return this.db.callFunctionJson<AuthListResult>('pro_listar_categorias', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_categoria', [id]);
  }

  crear(nombre: string, descripcion: string | null, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_categoria', [
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
    return this.db.callFunctionJson<AuthSingleResult>('pro_actualizar_categoria', [
      id,
      nombre,
      descripcion,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_categoria', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
