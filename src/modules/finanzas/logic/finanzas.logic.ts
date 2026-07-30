import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { FinanzasModel, TipoCuenta } from '../models/finanzas.model';
import { FiltroCuentaDto } from '../dto/filtro-cuenta.dto';
import { RegistrarPagoDto } from '../dto/registrar-pago.dto';
import { CrearCuentaDto } from '../dto/crear-cuenta.dto';

@Injectable()
export class FinanzasLogic {
  constructor(private readonly finanzasModel: FinanzasModel) {}

  async listarCuentas(tipo: TipoCuenta, filtros: FiltroCuentaDto) {
    const result = await this.finanzasModel.listarCuentas(tipo, filtros);
    return mapListResult(result, filtros);
  }

  async crearCuenta(tipo: TipoCuenta, dto: CrearCuentaDto) {
    const result = await this.finanzasModel.crearCuenta(tipo, dto);
    return mapSingleResult(result, 'No se pudo crear la cuenta');
  }

  async obtenerCuenta(id: number, tipo: TipoCuenta) {
    const result = await this.finanzasModel.obtenerCuenta(id, tipo);
    return mapSingleResult(result, `Cuenta ${id} no encontrada`);
  }

  async registrarPago(tipo: TipoCuenta, dto: RegistrarPagoDto) {
    const result = await this.finanzasModel.registrarPago(tipo, dto);
    return mapSingleResult(result, 'No se pudo registrar el pago');
  }

  async anularPago(idPago: number, tipo: TipoCuenta, idUsuarioAuditoria?: number) {
    const result = await this.finanzasModel.anularPago(
      idPago,
      tipo,
      idUsuarioAuditoria,
    );
    return mapDeleteResult(result, `Pago ${idPago} no encontrado o ya anulado`);
  }

  resumen(tipo: TipoCuenta) {
    return this.finanzasModel.resumen(tipo);
  }

  listarMediosPago() {
    return this.finanzasModel.listarMediosPago();
  }
}
