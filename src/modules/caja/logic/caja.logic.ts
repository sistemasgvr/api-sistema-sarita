import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CajaModel } from '../models/caja.model';
import {
  AbrirCajaDto,
  CerrarCajaDto,
  CrearCajaDepositoDto,
  CrearCajaGastoDto,
  CrearCajaObservacionDto,
  FiltroCajaSesionesDto,
  FiltroLibroDiarioDto,
} from '../dto/caja.dto';

@Injectable()
export class CajaLogic {
  constructor(private readonly cajaModel: CajaModel) {}

  async abrirSesion(dto: AbrirCajaDto) {
    const result = await this.cajaModel.abrirSesion(dto);
    return mapSingleResult(result, 'No se pudo abrir la caja');
  }

  async cerrarSesion(id: number, dto: CerrarCajaDto) {
    const result = await this.cajaModel.cerrarSesion(id, dto);
    return mapSingleResult(result, `Sesión de caja ${id} no encontrada`);
  }

  async obtenerSesion(id: number) {
    const result = await this.cajaModel.obtenerSesion(id);
    return mapSingleResult(result, `Sesión de caja ${id} no encontrada`);
  }

  async obtenerDia(fecha: string, idSucursal?: number) {
    const result = await this.cajaModel.obtenerDia(fecha, idSucursal);
    return mapSingleResult(result, 'No se pudo obtener el snapshot de caja');
  }

  async listarSesiones(filtros: FiltroCajaSesionesDto) {
    const result = await this.cajaModel.listarSesiones(filtros);
    return mapListResult(result, filtros);
  }

  async listarPendienteCierre(idSucursal?: number) {
    const result = await this.cajaModel.listarPendienteCierre(idSucursal);
    return mapListResult(result, { pagina: 1, limite: 100, offset: 0 });
  }

  async crearGasto(dto: CrearCajaGastoDto) {
    const result = await this.cajaModel.crearGasto(dto);
    return mapSingleResult(result, 'No se pudo registrar el gasto');
  }

  async eliminarGasto(id: number, idUsuarioAuditoria?: number) {
    const result = await this.cajaModel.eliminarGasto(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Gasto ${id} no encontrado`);
  }

  async crearDeposito(dto: CrearCajaDepositoDto) {
    const result = await this.cajaModel.crearDeposito(dto);
    return mapSingleResult(result, 'No se pudo registrar el depósito');
  }

  async eliminarDeposito(id: number, idUsuarioAuditoria?: number) {
    const result = await this.cajaModel.eliminarDeposito(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Depósito ${id} no encontrado`);
  }

  async crearObservacion(dto: CrearCajaObservacionDto) {
    const result = await this.cajaModel.crearObservacion(dto);
    return mapSingleResult(result, 'No se pudo registrar la observación');
  }

  async eliminarObservacion(id: number, idUsuarioAuditoria?: number) {
    const result = await this.cajaModel.eliminarObservacion(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Observación ${id} no encontrada`);
  }

  async obtenerLibroDiario(filtros: FiltroLibroDiarioDto) {
    const result = await this.cajaModel.obtenerLibroDiario(filtros);
    return mapSingleResult(result, 'No se pudo obtener el libro diario');
  }
}
