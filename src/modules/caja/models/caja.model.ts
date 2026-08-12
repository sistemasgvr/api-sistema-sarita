import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
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
export class CajaModel {
  constructor(private readonly db: DatabaseService) {}

  abrirSesion(dto: AbrirCajaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_abrir_caja_sesion', [
      dto.fecha,
      dto.montoInicial,
      dto.idSucursal ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  cerrarSesion(id: number, dto: CerrarCajaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_cerrar_caja_sesion', [
      id,
      dto.montoEfectivoContado,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  obtenerSesion(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_obtener_caja_sesion', [id]);
  }

  obtenerDia(fecha: string, idSucursal?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_obtener_caja_dia', [
      fecha,
      idSucursal ?? null,
    ]);
  }

  listarSesiones(filtros: FiltroCajaSesionesDto) {
    return this.db.callFunctionJson<AuthListResult>('fin_listar_caja_sesiones', [
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.idSucursal ?? null,
      filtros.estadoCaja ?? null,
      filtros.limite ?? 20,
      filtros.offset,
    ]);
  }

  listarPendienteCierre(idSucursal?: number) {
    return this.db.callFunctionJson<AuthListResult>('fin_listar_caja_pendiente_cierre', [
      idSucursal ?? null,
    ]);
  }

  crearGasto(dto: CrearCajaGastoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_crear_caja_gasto', [
      dto.fecha,
      dto.concepto,
      dto.monto,
      dto.idMedioPago ?? null,
      dto.idCategoriaGasto ?? null,
      dto.numeroOperacion ?? null,
      dto.observacion ?? null,
      dto.idSesion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminarGasto(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('fin_eliminar_caja_gasto', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  crearDeposito(dto: CrearCajaDepositoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_crear_caja_deposito', [
      dto.fecha,
      dto.monto,
      dto.idCuentaBancaria ?? null,
      dto.idMedioPago ?? null,
      dto.numeroOperacion ?? null,
      dto.observacion ?? null,
      dto.idSesion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminarDeposito(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('fin_eliminar_caja_deposito', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  crearObservacion(dto: CrearCajaObservacionDto) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_crear_caja_observacion', [
      dto.fecha,
      dto.texto,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminarObservacion(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('fin_eliminar_caja_observacion', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  obtenerLibroDiario(filtros: FiltroLibroDiarioDto) {
    return this.db.callFunctionJson<AuthSingleResult>('fin_obtener_libro_diario', [
      filtros.fechaDesde,
      filtros.fechaHasta ?? null,
      filtros.idCliente ?? null,
      filtros.idSucursal ?? null,
    ]);
  }
}
