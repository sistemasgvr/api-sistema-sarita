import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';

@Injectable()
export class EmpresasModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroPaginacionDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_empresas', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_obtener_empresa', [
      id,
    ]);
  }

  crear(
    ruc: string,
    razonSocial: string | null,
    nombreComercial: string | null,
    direccion: string | null,
    telefono: string | null,
    email: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_crear_empresa', [
      ruc,
      razonSocial,
      nombreComercial,
      direccion,
      telefono,
      email,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    ruc: string | null,
    razonSocial: string | null,
    nombreComercial: string | null,
    direccion: string | null,
    telefono: string | null,
    email: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_actualizar_empresa', [
      id,
      ruc,
      razonSocial,
      nombreComercial,
      direccion,
      telefono,
      email,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_empresa', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
