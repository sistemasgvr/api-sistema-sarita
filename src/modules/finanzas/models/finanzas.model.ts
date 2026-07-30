import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroCuentaDto } from '../dto/filtro-cuenta.dto';
import { RegistrarPagoDto } from '../dto/registrar-pago.dto';
import { CrearCuentaDto } from '../dto/crear-cuenta.dto';

export type TipoCuenta = 'COBRAR' | 'PAGAR';

@Injectable()
export class FinanzasModel {
  constructor(private readonly db: DatabaseService) {}

  listarCuentas(tipo: TipoCuenta, filtros: FiltroCuentaDto) {
    return this.db.callFunctionJson<AuthListResult>('fin_listar_cuentas', [
      tipo,
      filtros.idTercero ?? null,
      filtros.estado ?? null,
      filtros.soloPendientes ?? null,
      filtros.buscar ?? null,
      filtros.limite ?? 10,
      filtros.offset,
    ]);
  }

  crearCuenta(tipo: TipoCuenta, dto: CrearCuentaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_crear_cuenta', [
      tipo,
      dto.idTercero,
      dto.fechaEmision,
      dto.fechaVencimiento ?? null,
      dto.monto,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  obtenerCuenta(id: number, tipo: TipoCuenta) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_obtener_cuenta', [
      id,
      tipo,
    ]);
  }

  registrarPago(tipo: TipoCuenta, dto: RegistrarPagoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_registrar_pago', [
      dto.idCuenta,
      tipo,
      dto.fechaPago ?? null,
      dto.monto,
      dto.idMedioPago ?? null,
      dto.referencia ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  anularPago(idPago: number, tipo: TipoCuenta, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('fin_anular_pago', [
      idPago,
      tipo,
      idUsuarioAuditoria ?? null,
    ]);
  }

  resumen(tipo: TipoCuenta) {
    return this.db.callFunctionJson('fin_resumen_cuentas', [tipo]);
  }

  listarMediosPago() {
    return this.db.callFunctionJson('fin_listar_medios_pago');
  }
}
