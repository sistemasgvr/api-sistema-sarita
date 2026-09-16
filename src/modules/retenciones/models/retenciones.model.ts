import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import type { RetencionDetalleDto } from '../dto/retencion.dto';
import type { RetencionCompletoResult, RetencionListResult } from '../interfaces/retencion.interface';

/** El DTO llega en camelCase; la función SQL lee las claves en snake_case. */
function detalleASql(d: RetencionDetalleDto) {
  return {
    id_compra: d.idCompra ?? null,
    fecha_retencion: d.fechaRetencion,
    imp_retenido: d.impRetenido,
    imp_pagar: d.impPagar,
    tipo_doc: d.tipoDoc,
    num_doc: d.numDoc,
    fecha_emision: d.fechaEmision,
    moneda: d.moneda ?? 'PEN',
    imp_total: d.impTotal,
  };
}

@Injectable()
export class RetencionesModel {
  constructor(private readonly db: DatabaseService) {}

  async crear(params: {
    serie: string;
    fechaEmision: string;
    idEmpresa: number;
    idProveedor: number;
    idSucursal?: number;
    regimen: string;
    tasa: number;
    baseImponible: number;
    montoRetenido: number;
    montoPagado: number;
    observacion?: string;
    detalles?: RetencionDetalleDto[];
    idUsuarioAuditoria?: number;
  }): Promise<{ id: number; serie: string; numero: string; error?: string }> {
    return this.db.callFunctionJson<{ id: number; serie: string; numero: string; error?: string }>('com_crear_retencion', [
      params.serie,
      params.fechaEmision,
      params.idEmpresa,
      params.idProveedor,
      params.idSucursal ?? null,
      params.regimen,
      params.tasa,
      params.baseImponible,
      params.montoRetenido,
      params.montoPagado,
      params.observacion ?? null,
      JSON.stringify((params.detalles ?? []).map(detalleASql)),
      params.idUsuarioAuditoria ?? null,
    ]);
  }

  async obtener(id: number): Promise<RetencionCompletoResult> {
    return this.db.callFunctionJson<RetencionCompletoResult>('com_obtener_retencion', [id]);
  }

  async listar(params: {
    idEmpresa?: number;
    fechaDesde?: string;
    fechaHasta?: string;
    idProveedor?: number;
    pagina?: number;
    tamano?: number;
  }): Promise<RetencionListResult> {
    return this.db.callFunctionJson<RetencionListResult>('com_listar_retenciones', [
      params.idEmpresa ?? null,
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
      params.idProveedor ?? null,
      null,
      params.pagina ?? 1,
      params.tamano ?? 20,
    ]);
  }

  async registrarRespuestaSunat(id: number, params: {
    idEstadoSunat?: number;
    ticketSunat?: string;
    hashDocumento?: string;
    xmlFirmado?: string;
    cdrRespuesta?: string;
    idUsuarioAuditoria?: number;
  }): Promise<RetencionCompletoResult> {
    return this.db.callFunctionJson<RetencionCompletoResult>('com_registrar_respuesta_sunat_retencion', [
      id,
      params.idEstadoSunat ?? null,
      params.ticketSunat ?? null,
      params.hashDocumento ?? null,
      params.xmlFirmado ?? null,
      params.cdrRespuesta ?? null,
      params.idUsuarioAuditoria ?? null,
    ]);
  }
}
