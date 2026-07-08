import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateBalonesDto,
  DarBajaBalonDto,
  FiltroBalonesDto,
  FiltroPhHistorialDto,
  RegistrarPhHistorialDto,
  UpdateBalonesDto,
} from '../dto/balones.dto';
import { BalonesModel } from '../models/balones.model';

@Injectable()
export class BalonesLogic {
  constructor(private readonly model: BalonesModel) {}

  async listar(filtros: FiltroBalonesDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Balón ${id} no encontrado`);
  }

  async crear(dto: CreateBalonesDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdateBalonesDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Balón ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Balón ${id} no encontrado`);
  }

  async listarPhHistorial(idBalon: number, filtros: FiltroPhHistorialDto) {
    const result = await this.model.listarPhHistorial(idBalon, filtros);
    return mapListResult(result, filtros);
  }

  async registrarPhHistorial(idBalon: number, dto: RegistrarPhHistorialDto) {
    const result = await this.model.registrarPhHistorial(idBalon, dto);
    return mapSingleResult(result, 'No se pudo registrar la prueba hidrostática');
  }

  async obtenerBajaPorBalon(idBalon: number) {
    const result = await this.model.obtenerBajaPorBalon(idBalon);

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    return result.registro ?? null;
  }

  async darBaja(idBalon: number, dto: DarBajaBalonDto) {
    const result = await this.model.darBaja(idBalon, dto);
    return mapSingleResult(result, 'No se pudo dar de baja el balón');
  }
}
