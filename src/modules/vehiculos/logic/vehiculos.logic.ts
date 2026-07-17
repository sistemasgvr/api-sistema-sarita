import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateVehiculoDto,
  FiltroVehiculoDto,
  UpdateVehiculoDto,
} from '../dto/vehiculos.dto';
import { VehiculosModel } from '../models/vehiculos.model';

@Injectable()
export class VehiculosLogic {
  constructor(private readonly vehiculosModel: VehiculosModel) {}

  async listar(filtros: FiltroVehiculoDto) {
    const result = await this.vehiculosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.vehiculosModel.obtenerPorId(id);
    return mapSingleResult(result, `Vehículo ${id} no encontrado`);
  }

  async crear(dto: CreateVehiculoDto) {
    const result = await this.vehiculosModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el vehículo');
  }

  async actualizar(id: number, dto: UpdateVehiculoDto) {
    const result = await this.vehiculosModel.actualizar(id, dto);
    return mapSingleResult(result, `Vehículo ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.vehiculosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Vehículo ${id} no encontrado o ya está inactivo`);
  }
}
