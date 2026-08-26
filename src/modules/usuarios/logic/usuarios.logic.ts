import { Injectable } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateUsuarioDto, UpdateUsuarioDto } from '../dto/usuarios.dto';
import { FiltroUsuarioDto } from '../dto/filtros-usuario.dto';
import { UsuariosModel } from '../models/usuarios.model';
import { UsuariosRolesLogic } from '../../usuarios-roles/logic/usuarios-roles.logic';

@Injectable()
export class UsuariosLogic {
  constructor(
    private readonly usuariosModel: UsuariosModel,
    private readonly usuariosRolesLogic: UsuariosRolesLogic,
  ) {}

  async listar(filtros: FiltroUsuarioDto) {
    const result = await this.usuariosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.usuariosModel.obtenerPorId(id);
    return mapSingleResult(result, `Usuario ${id} no encontrado`);
  }

  async crear(dto: CreateUsuarioDto) {
    const hash = await UsuariosModel.hashPassword(dto.contrasena);
    const result = await this.usuariosModel.crear(
      dto.nombre,
      dto.correo,
      hash,
      dto.idTrabajador ?? null,
      dto.idUsuarioAuditoria,
    );
    const usuario = mapSingleResult(result, 'No se pudo crear el usuario');
    if (dto.idRol) {
      await this.usuariosRolesLogic.asignar({
        idUsuario: (usuario as { id: number }).id,
        idRol: dto.idRol,
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      });
    }

    return usuario;
  }

  async actualizar(id: number, dto: UpdateUsuarioDto) {
    const hash = dto.contrasena
      ? await UsuariosModel.hashPassword(dto.contrasena)
      : null;

    const result = await this.usuariosModel.actualizar(
      id,
      dto.nombre ?? null,
      dto.correo ?? null,
      hash,
      dto.idTrabajador ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Usuario ${id} no encontrado`);
  }

  async eliminar(id: number) {
    const result = await this.usuariosModel.eliminar(id);
    return mapDeleteResult(result, `Usuario ${id} no encontrado o ya está desactivado`);
  }

  async activar(id: number) {
    const result = await this.usuariosModel.activar(id);
    return mapActivateResult(result, `Usuario ${id} no encontrado o ya está activo`);
  }
}
