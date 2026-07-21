import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateBalonesDto,
  AprobarBajaBalonDto,
  DarBajaBalonDto,
  FiltroBalonesDto,
  FiltroEstadoHistorialDto,
  FiltroPhHistorialDto,
  RechazarBajaBalonDto,
  RegistrarPhHistorialDto,
  RestaurarBalonDto,
  UpdateBalonesDto,
} from '../dto/balones.dto';

@Injectable()
export class BalonesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroBalonesDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_balones', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idTipoBalon ?? null,
      filtros.idAlmacen ?? null,
      filtros.idEstadoBalon ?? null,
      filtros.idClienteUbicacion ?? null,
      filtros.idMarcaCilindro ?? null,
      filtros.phVencida ?? null,
      filtros.phPorVencerDias ?? null,
      filtros.idClienteRelacionado ?? null,
      filtros.soloBajas ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_balon', [id]);
  }

  crear(dto: CreateBalonesDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_balon', [
      dto.codigoBalon ?? null,
      dto.libroCilindro ?? null,
      dto.paginaLibro ?? null,
      dto.fechaRegistro ?? null,
      dto.idAlmacen ?? null,
      dto.idClienteUbicacion ?? null,
      dto.idPropietario ?? null,
      dto.idClientePropietario ?? null,
      dto.idReferencia ?? null,
      dto.idTipoBalon ?? null,
      dto.idProductoGas ?? null,
      dto.idEstadoBalon ?? null,
      dto.fechaUltimaPruebaHidrostatica ?? null,
      dto.vigenciaPruebaHidrostaticaAnios ?? null,
      dto.fechaProximaPruebaHidrostatica ?? null,
      dto.fechaFabricacion ?? null,
      dto.numeroRecepcion ?? null,
      dto.presionActual ?? null,
      dto.observacion ?? null,
      dto.numeroSerie ?? null,
      dto.idMarcaCilindro ?? null,
      dto.idOrganoInspector ?? null,
      dto.organoInspectorNoAplica ?? false,
      dto.anioFabricacion ?? null,
      dto.mesFabricacion ?? null,
      dto.idPlanta ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateBalonesDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_actualizar_balon', [
      id,
      dto.codigoBalon ?? null,
      dto.libroCilindro ?? null,
      dto.paginaLibro ?? null,
      dto.fechaRegistro ?? null,
      dto.idAlmacen ?? null,
      dto.idClienteUbicacion ?? null,
      dto.idPropietario ?? null,
      dto.idClientePropietario ?? null,
      dto.idReferencia ?? null,
      dto.idTipoBalon ?? null,
      dto.idProductoGas ?? null,
      dto.idEstadoBalon ?? null,
      dto.fechaUltimaPruebaHidrostatica ?? null,
      dto.vigenciaPruebaHidrostaticaAnios ?? null,
      dto.fechaProximaPruebaHidrostatica ?? null,
      dto.fechaFabricacion ?? null,
      dto.numeroRecepcion ?? null,
      dto.presionActual ?? null,
      dto.observacion ?? null,
      dto.numeroSerie ?? null,
      dto.idMarcaCilindro ?? null,
      dto.idOrganoInspector ?? null,
      dto.organoInspectorNoAplica ?? null,
      dto.anioFabricacion ?? null,
      dto.mesFabricacion ?? null,
      dto.idPlanta ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_balon', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  listarPhHistorial(idBalon: number, filtros: FiltroPhHistorialDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_ph_historial', [
      idBalon,
      filtros.limite ?? 50,
      filtros.offset,
    ]);
  }

  registrarPhHistorial(idBalon: number, dto: RegistrarPhHistorialDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_registrar_ph_historial', [
      idBalon,
      dto.fechaPrueba ?? null,
      dto.vigenciaAnios ?? null,
      dto.idOrganoInspector ?? null,
      dto.organoInspectorNoAplica ?? false,
      dto.numeroCertificado ?? null,
      dto.idMantenimiento ?? null,
      dto.idMovimientoRecarga ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  obtenerBajaPorBalon(idBalon: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_baja_por_balon', [idBalon]);
  }

  darBaja(idBalon: number, dto: DarBajaBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_solicitar_baja_balon', [
      idBalon,
      dto.idMotivoBaja ?? null,
      dto.idUsuarioSolicita ?? null,
      dto.motivoDetalle ?? null,
      dto.idClienteComprador ?? null,
      dto.idComprobanteVenta ?? null,
      dto.serieComprobante ?? null,
      dto.numeroComprobante ?? null,
      dto.montoVenta ?? null,
      dto.observacion ?? null,
      dto.fechaBaja ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  listarSolicitudesBaja(filtros: FiltroPaginacionDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_solicitudes_baja', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      'PENDIENTE',
    ]);
  }

  aprobarBaja(idBaja: number, dto: AprobarBajaBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_aprobar_baja_balon', [
      idBaja,
      dto.idUsuarioAutoriza ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  rechazarBaja(idBaja: number, dto: RechazarBajaBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_rechazar_baja_balon', [
      idBaja,
      dto.idUsuarioAutoriza ?? null,
      dto.motivoRechazo ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  listarEstadoHistorial(idBalon: number, filtros: FiltroEstadoHistorialDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_estado_historial', [
      idBalon,
      filtros.limite ?? 50,
      filtros.offset,
    ]);
  }

  restaurar(idBalon: number, dto: RestaurarBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_restaurar_balon', [
      idBalon,
      dto.idUsuarioAuditoria ?? null,
      dto.observacion ?? null,
      dto.idAlmacen ?? null,
    ]);
  }
}
