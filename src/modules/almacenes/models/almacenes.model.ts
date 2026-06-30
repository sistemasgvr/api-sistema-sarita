import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroAlmacenesDto } from '../dto/almacenes.dto';

@Injectable()
export class AlmacenesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroAlmacenesDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_almacenes', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idSucursal ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_obtener_almacen', [
      id,
    ]);
  }

  crear(
    idSucursal: number,
    nombre: string,
    ubicacion: string | null,
    descripcion: string | null,
    idDepartamento: number | null,
    idProvincia: number | null,
    idDistrito: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_crear_almacen', [
      idSucursal,
      nombre,
      ubicacion,
      descripcion,
      idDepartamento,
      idProvincia,
      idDistrito,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    idSucursal: number | null,
    nombre: string | null,
    ubicacion: string | null,
    descripcion: string | null,
    idDepartamento: number | null,
    idProvincia: number | null,
    idDistrito: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_actualizar_almacen', [
      id,
      idSucursal,
      nombre,
      ubicacion,
      descripcion,
      idDepartamento,
      idProvincia,
      idDistrito,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_almacen', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
