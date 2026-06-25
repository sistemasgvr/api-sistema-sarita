import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateUsuarioDto, UpdateUsuarioDto } from '../dto/usuarios.dto';
import { UsuariosModel } from '../models/usuarios.model';

@Injectable()
export class UsuariosLogic {
  constructor(private readonly usuariosModel: UsuariosModel) {}

  async listar(filtros: FiltroPaginacionDto) {
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
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear el usuario');
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
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Usuario ${id} no encontrado`);
  }

  async eliminar(id: number) {
    const result = await this.usuariosModel.eliminar(id);
    return mapDeleteResult(result, `Usuario ${id} no encontrado`);
  }
}
