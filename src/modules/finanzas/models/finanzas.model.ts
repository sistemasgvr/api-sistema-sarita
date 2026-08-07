import { Injectable, Logger } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroCuentaDto } from '../dto/filtro-cuenta.dto';
import { RegistrarPagoDto } from '../dto/registrar-pago.dto';
import { CrearCuentaCuotasDto, CrearCuentaDto } from '../dto/crear-cuenta.dto';
import { ActualizarCuentaDto } from '../dto/actualizar-cuenta.dto';
import {
  ActualizarGarantiaDto,
  CrearGarantiaDto,
  FiltroGarantiaDto,
  ReembolsarGarantiaDto,
} from '../dto/garantia.dto';
import { VerificarDuplicadoPagoDto } from '../dto/verificar-duplicado.dto';

export type TipoCuenta = 'COBRAR' | 'PAGAR';

@Injectable()
export class FinanzasModel {
  private readonly logger = new Logger(FinanzasModel.name);

  constructor(private readonly db: DatabaseService) {}

  listarCuentas(tipo: TipoCuenta, filtros: FiltroCuentaDto) {
    return this.db.callFunctionJson<AuthListResult>('fin_listar_cuentas', [
      tipo,
      filtros.idTercero ?? null,
      filtros.estado ?? null,
      filtros.soloPendientes ?? null,
      filtros.buscar ?? null,
      filtros.idPadre ?? null,
      filtros.limite ?? 10,
      filtros.offset,
    ]);
  }

  crearCuenta(tipo: TipoCuenta, dto: CrearCuentaDto) {
    const params = [
      tipo,
      dto.idTercero ?? null,
      dto.terceroNombre ?? null,
      dto.fechaEmision,
      dto.fechaVencimiento ?? null,
      dto.monto,
      dto.descripcion ?? null,
      dto.observacion ?? null,
      dto.idBanco ?? null,
      dto.tasaInteres ?? null,
      dto.numeroComprobante ?? null,
      dto.idUsuarioAuditoria ?? null,
    ];
    this.logger.debug(
      `fin_crear_cuenta ← tipo=${JSON.stringify(tipo)} params=${JSON.stringify(params)}`,
    );
    return this.db.callFunctionJson<AuthSingleResult>('fin_crear_cuenta', params);
  }

  actualizarCuenta(id: number, tipo: TipoCuenta, dto: ActualizarCuentaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_actualizar_cuenta', [
      id,
      tipo,
      dto.idTercero ?? null,
      dto.terceroNombre ?? null,
      dto.fechaEmision ?? null,
      dto.fechaVencimiento ?? null,
      dto.monto ?? null,
      dto.descripcion ?? null,
      dto.observacion ?? null,
      dto.numeroComprobante ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminarCuenta(id: number, tipo: TipoCuenta, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('fin_eliminar_cuenta', [
      id,
      tipo,
      idUsuarioAuditoria ?? null,
    ]);
  }

  crearCuentaCuotas(tipo: TipoCuenta, dto: CrearCuentaCuotasDto) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_crear_cuenta_cuotas', [
      tipo,
      dto.idTercero ?? null,
      dto.terceroNombre ?? null,
      dto.fechaEmision,
      dto.montoTotal,
      dto.numeroCuotas,
      dto.fechaPrimeraCuota,
      dto.diaMesPago,
      dto.descripcion ?? null,
      dto.observacion ?? null,
      dto.idBanco ?? null,
      dto.tasaInteres ?? null,
      dto.numeroComprobante ?? null,
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
      dto.idCuentaBancaria ?? null,
      dto.numeroOperacion ?? null,
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

  /* ==================== Garantías (ven_garantia: POS / préstamos / alquileres) ==================== */

  crearGarantia(dto: CrearGarantiaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_crear_garantia', [
      dto.idCliente,
      dto.importe,
      dto.idComprobante ?? null,
      dto.idPrestamo ?? null,
      dto.idProducto ?? null,
      null,
      null,
      null,
      dto.fecha ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.idAlquiler ?? null,
      dto.idMedioPago ?? null,
    ]);
  }

  actualizarGarantia(id: number, dto: ActualizarGarantiaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_actualizar_garantia_manual', [
      id,
      dto.fecha ?? null,
      dto.idCliente ?? null,
      dto.idMedioPago ?? null,
      dto.importe ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  listarGarantias(filtros: FiltroGarantiaDto) {
    return this.db.callFunctionJson<AuthListResult>('ven_listar_garantias', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idCliente ?? null,
      null,
      null,
      null,
      filtros.estado ?? null,
      filtros.desde ?? null,
      filtros.hasta ?? null,
    ]);
  }

  obtenerGarantia(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_obtener_garantia', [id]);
  }

  eliminarGarantia(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('ven_eliminar_garantia', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  reembolsarGarantia(id: number, dto: ReembolsarGarantiaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_devolver_garantia', [
      id,
      dto.monto,
      dto.idComprobante ?? null,
      dto.fecha ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.idMedioReembolso ?? null,
    ]);
  }

  verificarDuplicadoPago(dto: VerificarDuplicadoPagoDto) {
    return this.db.callFunctionJson<{
      duplicado: boolean;
      severidad?: 'alta' | 'media';
      mensaje?: string;
      pagoExistente?: unknown;
    }>('fin_verificar_duplicado_pago', [
      dto.idCuenta,
      dto.fechaPago,
      dto.monto,
      dto.diasVentana ?? 7,
      dto.numeroComprobante ?? null,
    ]);
  }
}
