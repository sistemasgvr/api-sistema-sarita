import { ConflictException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { FinanzasModel, TipoCuenta } from '../models/finanzas.model';
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
import { FiltroSaldosPorTerceroDto } from '../dto/filtro-saldos-tercero.dto';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import {
  TipoNotificacion,
  TipoReferenciaNotificacion,
} from '../../notificaciones/constants/tipo-notificacion';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { ResponseHelper } from '../../../common/helpers/response.helper';

@Injectable()
export class FinanzasLogic {
  constructor(
    private readonly finanzasModel: FinanzasModel,
    private readonly notificacionesLogic: NotificacionesLogic,
  ) {}

  /* ==================== Cuentas ==================== */

  async listarCuentas(tipo: TipoCuenta, filtros: FiltroCuentaDto) {
    const result = await this.finanzasModel.listarCuentas(tipo, filtros);
    return mapListResult(result, filtros);
  }

  async listarSaldosPorTercero(tipo: TipoCuenta, filtros: FiltroSaldosPorTerceroDto) {
    const result = await this.finanzasModel.listarSaldosPorTercero(tipo, filtros);
    const pagina = filtros.pagina ?? 1;
    const limite = filtros.limite ?? 50;
    return ResponseHelper.paginated(result.registros ?? [], {
      pagina,
      limite,
      total: Number(result.total ?? 0),
      resumen: (result.resumen ?? null) as Record<string, unknown> | null,
    });
  }

  async crearCuenta(tipo: TipoCuenta, dto: CrearCuentaDto) {
    const result = await this.finanzasModel.crearCuenta(tipo, dto);
    const cuenta = mapSingleResult(result, 'No se pudo crear la cuenta');
    await this.notificarCuentaCreada(tipo, cuenta, dto.idUsuarioAuditoria);
    return cuenta;
  }

  async crearCuentaCuotas(tipo: TipoCuenta, dto: CrearCuentaCuotasDto) {
    const result = await this.finanzasModel.crearCuentaCuotas(tipo, dto);
    const cuenta = mapSingleResult(result, 'No se pudo crear el plan de cuotas');
    await this.notificarCuentaCreada(tipo, cuenta, dto.idUsuarioAuditoria);
    return cuenta;
  }

  async actualizarCuenta(id: number, tipo: TipoCuenta, dto: ActualizarCuentaDto) {
    const result = await this.finanzasModel.actualizarCuenta(id, tipo, dto);
    return mapSingleResult(result, `Cuenta ${id} no encontrada`);
  }

  async eliminarCuenta(id: number, tipo: TipoCuenta, idUsuarioAuditoria?: number) {
    const result = await this.finanzasModel.eliminarCuenta(id, tipo, idUsuarioAuditoria);
    const deleted = mapDeleteResult(result, `Cuenta ${id} no encontrada o ya está inactiva`);
    await this.notificarCuentaEliminada(tipo, id, idUsuarioAuditoria);
    return deleted;
  }

  async obtenerCuenta(id: number, tipo: TipoCuenta) {
    const result = await this.finanzasModel.obtenerCuenta(id, tipo);
    return mapSingleResult(result, `Cuenta ${id} no encontrada`);
  }

  /* ==================== Pagos ==================== */

  async verificarDuplicadoPago(dto: VerificarDuplicadoPagoDto) {
    return this.finanzasModel.verificarDuplicadoPago(dto);
  }

  async registrarPago(tipo: TipoCuenta, dto: RegistrarPagoDto) {
    // Chequeo de duplicados salvo que el usuario haya confirmado con forzarDuplicado=true
    if (!dto.forzarDuplicado) {
      const check = await this.finanzasModel.verificarDuplicadoPago({
        idCuenta: dto.idCuenta,
        fechaPago: dto.fechaPago ?? new Date().toISOString().slice(0, 10),
        monto: dto.monto,
      });
      if (check?.duplicado) {
        // 409 Conflict con el detalle del duplicado; el frontend abre confirm y reintenta con forzarDuplicado=true
        throw new ConflictException({
          message: check.mensaje ?? 'Posible pago duplicado',
          duplicado: check,
        });
      }
    }

    const result = await this.finanzasModel.registrarPago(tipo, dto);
    const pago = mapSingleResult(result, 'No se pudo registrar el pago');

    await this.notificarPagoRegistrado(tipo, pago, !!dto.forzarDuplicado, dto.idUsuarioAuditoria);
    return pago;
  }

  async anularPago(idPago: number, tipo: TipoCuenta, idUsuarioAuditoria?: number) {
    const result = await this.finanzasModel.anularPago(idPago, tipo, idUsuarioAuditoria);
    const deleted = mapDeleteResult(result, `Pago ${idPago} no encontrado o ya anulado`);
    await this.notificarPagoAnulado(tipo, idPago, idUsuarioAuditoria);
    return deleted;
  }

  resumen(tipo: TipoCuenta) {
    return this.finanzasModel.resumen(tipo);
  }

  listarMediosPago() {
    return this.finanzasModel.listarMediosPago();
  }

  /* ==================== Garantías ==================== */

  async listarGarantias(filtros: FiltroGarantiaDto) {
    const result = await this.finanzasModel.listarGarantias(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerGarantia(id: number) {
    const result = await this.finanzasModel.obtenerGarantia(id);
    return mapSingleResult(result, `Garantía ${id} no encontrada`);
  }

  async crearGarantia(dto: CrearGarantiaDto) {
    const result = await this.finanzasModel.crearGarantia(dto);
    const garantia = mapSingleResult(result, 'No se pudo registrar la garantía');
    await this.notificarGarantiaCreada(garantia, dto.idUsuarioAuditoria);
    return garantia;
  }

  async actualizarGarantia(id: number, dto: ActualizarGarantiaDto) {
    const result = await this.finanzasModel.actualizarGarantia(id, dto);
    return mapSingleResult(result, `Garantía ${id} no encontrada`);
  }

  async eliminarGarantia(id: number, idUsuarioAuditoria?: number) {
    const result = await this.finanzasModel.eliminarGarantia(id, idUsuarioAuditoria);
    const deleted = mapDeleteResult(result, `Garantía ${id} no encontrada`);
    await this.notificarGarantiaEliminada(id, idUsuarioAuditoria);
    return deleted;
  }

  async reembolsarGarantia(id: number, dto: ReembolsarGarantiaDto) {
    const result = await this.finanzasModel.reembolsarGarantia(id, dto);
    const garantia = mapSingleResult(result, `Garantía ${id} no encontrada`);
    await this.notificarGarantiaReembolsada(garantia, dto.idUsuarioAuditoria);
    return garantia;
  }

  /* ==================== Notificaciones (helpers privados) ==================== */

  private permisoVerPorTipo(tipo: TipoCuenta) {
    return tipo === 'COBRAR'
      ? PermisoBanderas.FINANZAS_CXC_VER
      : PermisoBanderas.FINANZAS_CXP_VER;
  }

  private etiqueta(tipo: TipoCuenta) {
    return tipo === 'COBRAR' ? 'cuenta por cobrar' : 'cuenta por pagar';
  }

  private async notificarCuentaCreada(
    tipo: TipoCuenta,
    cuenta: any,
    idUsuarioAuditoria?: number,
  ) {
    try {
      await this.notificacionesLogic.notificarPorPermiso({
        permiso: this.permisoVerPorTipo(tipo),
        codigoTipo: TipoNotificacion.FIN_CUENTA_CREADA,
        titulo: `Nueva ${this.etiqueta(tipo)}`,
        mensaje: `${cuenta?.tercero ?? 'Tercero'} · ${this.formatCurrency(cuenta?.monto_pendiente)}${cuenta?.descripcion ? ` · ${cuenta.descripcion}` : ''}`,
        payload: { idCuenta: cuenta?.id, tipo },
        idReferencia: cuenta?.id,
        tipoReferencia: TipoReferenciaNotificacion.CUENTA_FIN,
        claveDedupePrefix: `FIN_CUENTA_CREADA:${cuenta?.id}`,
        idUsuarioAuditoria,
        excluirUsuarioId: idUsuarioAuditoria,
      });
    } catch {
      /* no bloquea la creación si la notificación falla */
    }
  }

  private async notificarCuentaEliminada(
    tipo: TipoCuenta,
    idCuenta: number,
    idUsuarioAuditoria?: number,
  ) {
    try {
      await this.notificacionesLogic.notificarPorPermiso({
        permiso: this.permisoVerPorTipo(tipo),
        codigoTipo: TipoNotificacion.FIN_CUENTA_ELIMINADA,
        titulo: `${this.capitalize(this.etiqueta(tipo))} eliminada`,
        mensaje: `Se eliminó la ${this.etiqueta(tipo)} #${idCuenta}`,
        payload: { idCuenta, tipo },
        idReferencia: idCuenta,
        tipoReferencia: TipoReferenciaNotificacion.CUENTA_FIN,
        claveDedupePrefix: `FIN_CUENTA_ELIMINADA:${idCuenta}`,
        idUsuarioAuditoria,
        excluirUsuarioId: idUsuarioAuditoria,
      });
    } catch {
      /* ignora */
    }
  }

  private async notificarPagoRegistrado(
    tipo: TipoCuenta,
    pago: any,
    forzadoDuplicado: boolean,
    idUsuarioAuditoria?: number,
  ) {
    try {
      const codigoTipo = forzadoDuplicado
        ? TipoNotificacion.FIN_PAGO_DUPLICADO_FORZADO
        : TipoNotificacion.FIN_PAGO_REGISTRADO;
      const accion = tipo === 'COBRAR' ? 'Cobranza' : 'Pago';
      const titulo = forzadoDuplicado
        ? `${accion} registrada (posible duplicado forzado)`
        : `${accion} registrada`;

      await this.notificacionesLogic.notificarPorPermiso({
        permiso: this.permisoVerPorTipo(tipo),
        codigoTipo,
        titulo,
        mensaje: `Monto: ${this.formatCurrency(pago?.monto)} · Saldo restante: ${this.formatCurrency(pago?.saldoRestante)}`,
        payload: { idPago: pago?.id, idCuenta: pago?.idCuenta, tipo, forzadoDuplicado },
        idReferencia: pago?.id,
        tipoReferencia: TipoReferenciaNotificacion.PAGO_FIN,
        claveDedupePrefix: `FIN_PAGO:${pago?.id}`,
        idUsuarioAuditoria,
        excluirUsuarioId: idUsuarioAuditoria,
      });
    } catch {
      /* ignora */
    }
  }

  private async notificarPagoAnulado(
    tipo: TipoCuenta,
    idPago: number,
    idUsuarioAuditoria?: number,
  ) {
    try {
      await this.notificacionesLogic.notificarPorPermiso({
        permiso: this.permisoVerPorTipo(tipo),
        codigoTipo: TipoNotificacion.FIN_PAGO_ANULADO,
        titulo: 'Pago anulado',
        mensaje: `Se anuló el pago #${idPago}`,
        payload: { idPago, tipo },
        idReferencia: idPago,
        tipoReferencia: TipoReferenciaNotificacion.PAGO_FIN,
        claveDedupePrefix: `FIN_PAGO_ANULADO:${idPago}`,
        idUsuarioAuditoria,
        excluirUsuarioId: idUsuarioAuditoria,
      });
    } catch {
      /* ignora */
    }
  }

  private async notificarGarantiaCreada(garantia: any, idUsuarioAuditoria?: number) {
    try {
      await this.notificacionesLogic.notificarPorPermiso({
        permiso: PermisoBanderas.FINANZAS_GARANTIAS_VER,
        codigoTipo: TipoNotificacion.FIN_GARANTIA_CREADA,
        titulo: 'Nueva garantía registrada',
        mensaje: `${garantia?.nombre_cliente ?? 'Cliente'} · ${this.formatCurrency(garantia?.monto_cobrado)}`,
        payload: { idGarantia: garantia?.id, idCliente: garantia?.id_cliente },
        idReferencia: garantia?.id,
        tipoReferencia: TipoReferenciaNotificacion.GARANTIA,
        claveDedupePrefix: `FIN_GARANTIA_CREADA:${garantia?.id}`,
        idUsuarioAuditoria,
        excluirUsuarioId: idUsuarioAuditoria,
      });
    } catch {
      /* ignora */
    }
  }

  private async notificarGarantiaReembolsada(garantia: any, idUsuarioAuditoria?: number) {
    try {
      await this.notificacionesLogic.notificarPorPermiso({
        permiso: PermisoBanderas.FINANZAS_GARANTIAS_VER,
        codigoTipo: TipoNotificacion.FIN_GARANTIA_REEMBOLSADA,
        titulo: 'Garantía reembolsada',
        mensaje: `${garantia?.nombre_cliente ?? 'Cliente'} · saldo ${this.formatCurrency(garantia?.monto_saldo)}`,
        payload: {
          idGarantia: garantia?.id,
          idCliente: garantia?.id_cliente,
          montoSaldo: garantia?.monto_saldo,
          nombreEstado: garantia?.nombre_estado,
        },
        idReferencia: garantia?.id,
        tipoReferencia: TipoReferenciaNotificacion.GARANTIA,
        claveDedupePrefix: `FIN_GARANTIA_REEMBOLSADA:${garantia?.id}:${garantia?.monto_devuelto ?? 0}`,
        idUsuarioAuditoria,
        excluirUsuarioId: idUsuarioAuditoria,
      });
    } catch {
      /* ignora */
    }
  }

  private async notificarGarantiaEliminada(idGarantia: number, idUsuarioAuditoria?: number) {
    try {
      await this.notificacionesLogic.notificarPorPermiso({
        permiso: PermisoBanderas.FINANZAS_GARANTIAS_VER,
        codigoTipo: TipoNotificacion.FIN_GARANTIA_ELIMINADA,
        titulo: 'Garantía eliminada',
        mensaje: `Se eliminó la garantía #${idGarantia}`,
        payload: { idGarantia },
        idReferencia: idGarantia,
        tipoReferencia: TipoReferenciaNotificacion.GARANTIA,
        claveDedupePrefix: `FIN_GARANTIA_ELIMINADA:${idGarantia}`,
        idUsuarioAuditoria,
        excluirUsuarioId: idUsuarioAuditoria,
      });
    } catch {
      /* ignora */
    }
  }

  private formatCurrency(value: unknown): string {
    const n = Number(value);
    if (!Number.isFinite(n)) return '—';
    return new Intl.NumberFormat('es-PE', {
      style: 'currency',
      currency: 'PEN',
    }).format(n);
  }

  private capitalize(s: string) {
    return s.charAt(0).toUpperCase() + s.slice(1);
  }
}

