import { Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import {
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateSesionDto, ValidarSesionDto } from '../dto/create-sesion.dto';
import { FiltroSesionesDto } from '../dto/sesiones.dto';
import { SesionesModel } from '../models/sesiones.model';

@Injectable()
export class SesionesLogic {
  constructor(private readonly sesionesModel: SesionesModel) {}

  async listar(filtros: FiltroSesionesDto) {
    const result = await this.sesionesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.sesionesModel.obtenerPorId(id);
    return mapSingleResult(result, `Sesión ${id} no encontrada`);
  }

  async crear(dto: CreateSesionDto) {
    const result = await this.sesionesModel.crear(
      dto.idUsuario,
      dto.token,
      dto.ip ?? null,
      dto.userAgent ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la sesión');
  }

  async cerrar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.sesionesModel.cerrar(id, idUsuarioAuditoria);

    if (!result.cerrada) {
      throw new NotFoundException(`Sesión ${id} no encontrada o ya cerrada`);
    }

    return result;
  }

  async validar(dto: ValidarSesionDto) {
    const result = await this.sesionesModel.validar(dto.token);

    if (!result.valida || !result.registro) {
      throw new UnauthorizedException('Sesión inválida o expirada');
    }

    return result.registro;
  }
}
