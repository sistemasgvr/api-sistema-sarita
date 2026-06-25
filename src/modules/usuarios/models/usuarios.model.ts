import { Injectable } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

@Injectable()
export class UsuariosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroPaginacionDto) {
    return this.db.callFunctionJson<AuthListResult>('auth_listar_usuarios', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_obtener_usuario', [id]);
  }

  crear(
    nombre: string,
    correo: string,
    contrasenaHash: string,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_crear_usuario', [
      nombre,
      correo,
      contrasenaHash,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    nombre: string | null,
    correo: string | null,
    contrasenaHash: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_actualizar_usuario', [
      id,
      nombre,
      correo,
      contrasenaHash,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('auth_eliminar_usuario', [id]);
  }

  static async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, 10);
  }
}
