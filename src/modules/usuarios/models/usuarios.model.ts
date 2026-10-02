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

  async listar(filtros: FiltroUsuarioDto) {
    const result = await this.db.callFunctionJson<AuthListResult>('auth_listar_usuarios', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      this.resolveEstadoFiltro(filtros.estado),
    ]);
    if (result.registros?.length) result.registros = await this.conTrabajador(result.registros);
    return result;
  }

  async obtenerPorId(id: number) {
    const result = await this.db.callFunctionJson<AuthSingleResult>('auth_obtener_usuario', [id]);
    if (result.registro) [result.registro] = await this.conTrabajador([result.registro]);
    return result;
  }

  private async conTrabajador<T>(usuarios: T[]): Promise<T[]> {
    const ids = usuarios.map(usuario => (usuario as { id: number }).id);
    const { rows } = await this.db.query<{
      id: number; id_trabajador: number | null; nombre_trabajador: string | null;
    }>(`SELECT u.id, u.id_trabajador,
        NULLIF(TRIM(CONCAT_WS(' ', t.nombres, t.apellido_paterno, t.apellido_materno)), '') AS nombre_trabajador
      FROM auth_usuarios u
      LEFT JOIN tra_trabajadores t ON t.id = u.id_trabajador
      WHERE u.id = ANY($1::integer[])`, [ids]);
    const vinculos = new Map(rows.map(row => [row.id, row]));
    return usuarios.map(usuario => ({ ...usuario, ...vinculos.get((usuario as { id: number }).id) }));
  }

  crear(
    nombre: string,
    correo: string,
    contrasenaHash: string,
    idTrabajador?: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_crear_usuario', [
      nombre,
      correo,
      contrasenaHash,
      idTrabajador ?? null,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    nombre: string | null,
    correo: string | null,
    contrasenaHash: string | null,
    idTrabajador?: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_actualizar_usuario', [
      id,
      nombre,
      correo,
      contrasenaHash,
      idTrabajador ?? null,
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
