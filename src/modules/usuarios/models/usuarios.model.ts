import { Injectable } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthActivateResult,
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroUsuarioDto, UsuarioEstadoFiltro } from '../dto/filtros-usuario.dto';

@Injectable()
export class UsuariosModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: UsuarioEstadoFiltro): boolean | null {
    if (estado === 'inactivos') return false;
    if (estado === 'todos') return null;
    return true;
  }

  listar(filtros: FiltroUsuarioDto) {
    return this.db.callFunctionJson<AuthListResult>('auth_listar_usuarios', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      this.resolveEstadoFiltro(filtros.estado),
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

  activar(id: number) {
    return this.db.callFunctionJson<AuthActivateResult>('auth_activar_usuario', [id]);
  }

  static async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, 10);
  }
}
