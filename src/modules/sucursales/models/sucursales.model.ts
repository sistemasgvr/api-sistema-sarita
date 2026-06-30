import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';

@Injectable()
export class SucursalesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroPaginacionDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_sucursales', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_obtener_sucursal', [
      id,
    ]);
  }

  crear(
    codigo: string,
    nombre: string,
    direccion: string | null,
    idDepartamento: number | null,
    idProvincia: number | null,
    idDistrito: number | null,
    telefono: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_crear_sucursal', [
      codigo,
      nombre,
      direccion,
      idDepartamento,
      idProvincia,
      idDistrito,
      telefono,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    codigo: string | null,
    nombre: string | null,
    direccion: string | null,
    idDepartamento: number | null,
    idProvincia: number | null,
    idDistrito: number | null,
    telefono: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_actualizar_sucursal',
      [
        id,
        codigo,
        nombre,
        direccion,
        idDepartamento,
        idProvincia,
        idDistrito,
        telefono,
        idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_sucursal', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
