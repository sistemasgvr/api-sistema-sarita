import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateCuentaBancariaDto,
  FiltroCuentaBancariaDto,
  UpdateCuentaBancariaDto,
} from '../dto/cuentas-bancarias.dto';
import { CuentasBancariasModel } from '../models/cuentas-bancarias.model';

@Injectable()
export class CuentasBancariasLogic {
  constructor(private readonly cuentasBancariasModel: CuentasBancariasModel) {}

  async listar(filtros: FiltroCuentaBancariaDto) {
    const result = await this.cuentasBancariasModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.cuentasBancariasModel.obtenerPorId(id);
    return mapSingleResult(result, `Cuenta bancaria ${id} no encontrada`);
  }

  async crear(dto: CreateCuentaBancariaDto) {
    const result = await this.cuentasBancariasModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear la cuenta bancaria');
  }

  async actualizar(id: number, dto: UpdateCuentaBancariaDto) {
    const result = await this.cuentasBancariasModel.actualizar(id, dto);
    return mapSingleResult(result, `Cuenta bancaria ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.cuentasBancariasModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Cuenta bancaria ${id} no encontrada o ya está inactiva`);
  }
}
