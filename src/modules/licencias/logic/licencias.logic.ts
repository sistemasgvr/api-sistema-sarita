import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateLicenciaDto,
  FiltroLicenciaDto,
  UpdateLicenciaDto,
} from '../dto/licencias.dto';
import { LicenciasModel } from '../models/licencias.model';

@Injectable()
export class LicenciasLogic {
  constructor(private readonly licenciasModel: LicenciasModel) {}

  async listar(filtros: FiltroLicenciaDto) {
    const result = await this.licenciasModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.licenciasModel.obtenerPorId(id);
    return mapSingleResult(result, `Licencia ${id} no encontrada`);
  }

  async crear(dto: CreateLicenciaDto) {
    const result = await this.licenciasModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear la licencia');
  }

  async actualizar(id: number, dto: UpdateLicenciaDto) {
    const result = await this.licenciasModel.actualizar(id, dto);
    return mapSingleResult(result, `Licencia ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.licenciasModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Licencia ${id} no encontrada o ya está inactiva`);
  }
}
