import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateTrabajadorDto,
  FiltroTrabajadorDto,
  UpdateTrabajadorDto,
} from '../dto/trabajadores.dto';
import { UsuariosLogic } from '../../usuarios/logic/usuarios.logic';
import { TrabajadoresModel } from '../models/trabajadores.model';

@Injectable()
export class TrabajadoresLogic {
  constructor(
    private readonly trabajadoresModel: TrabajadoresModel,
    private readonly usuariosLogic: UsuariosLogic,
  ) {}

  async listar(filtros: FiltroTrabajadorDto) {
    const result = await this.trabajadoresModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.trabajadoresModel.obtenerPorId(id);
    return mapSingleResult(result, `Trabajador ${id} no encontrado`);
  }

  async crear(dto: CreateTrabajadorDto) {
    if (dto.crearUsuario) {
      dto.idUsuarioVinculo = await this.crearUsuarioParaTrabajador(dto);
    }
    const result = await this.trabajadoresModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el trabajador');
  }

  async actualizar(id: number, dto: UpdateTrabajadorDto) {
    if (dto.crearUsuario) {
      dto.idUsuarioVinculo = await this.crearUsuarioParaTrabajador(dto as CreateTrabajadorDto);
    }
    const result = await this.trabajadoresModel.actualizar(id, dto);
    return mapSingleResult(result, `Trabajador ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.trabajadoresModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Trabajador ${id} no encontrado o ya está inactivo`);
  }

  private async crearUsuarioParaTrabajador(dto: CreateTrabajadorDto): Promise<number> {
    if (!dto.correo || !dto.numeroDocumento) {
      throw new BadRequestException(
        'Para crear el usuario de acceso se requiere el correo y el número de documento del trabajador',
      );
    }

    const nombre = [dto.nombres, dto.apellidoPaterno, dto.apellidoMaterno]
      .filter((v): v is string => Boolean(v))
      .join(' ')
      .trim();

    const usuario = await this.usuariosLogic.crear({
      nombre: nombre || dto.nombres || 'Trabajador',
      correo: dto.correo,
      contrasena: dto.numeroDocumento,
      idUsuarioAuditoria: dto.idUsuarioAuditoria,
    });

    return (usuario as { id: number }).id;
  }
}
