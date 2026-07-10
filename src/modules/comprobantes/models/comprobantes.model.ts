import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  ComprobanteCuotaDto,
  ComprobanteDetalleDto,
  CreateComprobantesDto,
  FiltroComprobantesDto,
  RegistrarRespuestaSunatDto,
  SiguienteNumeroQueryDto,
  UpdateComprobantesDto,
} from '../dto/comprobantes.dto';

export interface SiguienteNumeroResult {
  serie: string;
  id_tipo_comprobante: number;
  ultimo_numero: string | null;
  numero: string;
  error?: string;
}

function mapDetallesToJson(detalles: ComprobanteDetalleDto[]) {
  return detalles.map((d) => ({
    id_producto: d.idProducto,
    cantidad: d.cantidad,
    precio_unitario: d.precioUnitario,
    descuento: d.descuento ?? 0,
    porcentaje_igv: d.porcentajeIgv ?? 18,
    id_afectacion_igv: d.idAfectacionIgv ?? null,
    descripcion: d.descripcion ?? null,
    id_unidad_medida: d.idUnidadMedida ?? null,
    item: d.item ?? null,
    id_balon: d.idBalon ?? null,
    capacidad_cilindro: d.capacidadCilindro ?? null,
    id_estado_cilindro: d.idEstadoCilindro ?? null,
  }));
}

function mapCuotasToJson(cuotas?: ComprobanteCuotaDto[]) {
  if (!cuotas?.length) return null;

  return cuotas.map((c) => ({
    numero_cuota: c.numeroCuota,
    fecha_vencimiento: c.fechaVencimiento,
    monto: c.monto,
    monto_pagado: c.montoPagado ?? 0,
    id_estado: c.idEstado ?? null,
  }));
}

@Injectable()
export class ComprobantesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroComprobantesDto) {
    return this.db.callFunctionJson<AuthListResult>('ven_listar_comprobantes', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idTipoComprobante ?? null,
      filtros.idCliente ?? null,
      filtros.idEstado ?? null,
      filtros.idEstadoSunat ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.serie ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_obtener_comprobante', [id]);
  }

  obtenerSiguienteNumero(query: SiguienteNumeroQueryDto) {
    return this.db.callFunctionJson<SiguienteNumeroResult>('ven_obtener_siguiente_numero', [
      query.idTipoComprobante,
      query.serie,
    ]);
  }

  crear(dto: CreateComprobantesDto) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_crear_comprobante', [
      dto.idTipoComprobante,
      dto.serie,
      dto.numero ?? null,
      dto.fecha,
      dto.idCliente,
      mapDetallesToJson(dto.detalles),
      dto.idTipoOperacionSunat ?? null,
      dto.idComprobanteOrigen ?? null,
      dto.idMotivoNota ?? null,
      dto.idTipoMovimiento ?? null,
      dto.idTipoVenta ?? null,
      dto.fechaVencimiento ?? null,
      dto.tipoCambio ?? 3.5,
      dto.idSucursal ?? null,
      dto.idAlmacen ?? null,
      dto.idCondicionPago ?? null,
      dto.idMoneda ?? null,
      dto.idMedioPago ?? null,
      dto.glosa ?? null,
      dto.observaciones ?? null,
      dto.periodoContable ?? null,
      dto.operacion ?? null,
      dto.idEstado ?? null,
      mapCuotasToJson(dto.cuotas),
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateComprobantesDto) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_actualizar_comprobante', [
      id,
      dto.fecha ?? null,
      dto.idCliente ?? null,
      dto.detalles ? mapDetallesToJson(dto.detalles) : null,
      dto.idTipoOperacionSunat ?? null,
      dto.idComprobanteOrigen ?? null,
      dto.idMotivoNota ?? null,
      dto.idTipoMovimiento ?? null,
      dto.idTipoVenta ?? null,
      dto.fechaVencimiento ?? null,
      dto.tipoCambio ?? null,
      dto.idSucursal ?? null,
      dto.idAlmacen ?? null,
      dto.idCondicionPago ?? null,
      dto.idMoneda ?? null,
      dto.idMedioPago ?? null,
      dto.glosa ?? null,
      dto.observaciones ?? null,
      dto.periodoContable ?? null,
      dto.operacion ?? null,
      dto.idEstado ?? null,
      dto.cuotas !== undefined ? mapCuotasToJson(dto.cuotas) : null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('ven_eliminar_comprobante', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  registrarRespuestaSunat(id: number, dto: RegistrarRespuestaSunatDto) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_registrar_respuesta_sunat', [
      id,
      dto.idEstadoSunat ?? null,
      dto.ticketSunat ?? null,
      dto.hashDocumento ?? null,
      dto.xmlFirmado ?? null,
      dto.cdrRespuesta ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }
}
