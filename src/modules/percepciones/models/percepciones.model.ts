import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import type { PercepcionDetalleDto } from '../dto/percepcion.dto';
import type { PercepcionCompletoResult, PercepcionListResult } from '../interfaces/percepcion.interface';

/** El DTO llega en camelCase; la función SQL lee las claves en snake_case. */
function detalleASql(d: PercepcionDetalleDto) {
  return {
    id_comprobante: d.idComprobante ?? null,
    fecha_percepcion: d.fechaPercepcion,
    imp_percibido: d.impPercibido,
    imp_cobrar: d.impCobrar,
    tipo_doc: d.tipoDoc,
    num_doc: d.numDoc,
    fecha_emision: d.fechaEmision,
    moneda: d.moneda ?? 'PEN',
    imp_total: d.impTotal,
  };
}

@Injectable()
export class PercepcionesModel {
  constructor(private readonly db: DatabaseService) {}

  async crear(params: {
    serie: string;
    fechaEmision: string;
    idEmpresa: number;
    idCliente: number;
    idSucursal?: number;
    regimen: string;
    tasa: number;
    baseImponible: number;
    montoPercibido: number;
    montoCobrado: number;
    observacion?: string;
    detalles?: PercepcionDetalleDto[];
    idUsuarioAuditoria?: number;
  }): Promise<{ id: number; serie: string; numero: string; error?: string }> {
    return this.db.callFunctionJson<{ id: number; serie: string; numero: string; error?: string }>('ven_crear_percepcion', [
      params.serie,
      params.fechaEmision,
      params.idEmpresa,
      params.idCliente,
      params.idSucursal ?? null,
      params.regimen,
      params.tasa,
      params.baseImponible,
      params.montoPercibido,
      params.montoCobrado,
      params.observacion ?? null,
      JSON.stringify((params.detalles ?? []).map(detalleASql)),
      params.idUsuarioAuditoria ?? null,
    ]);
  }

  async obtener(id: number): Promise<PercepcionCompletoResult> {
    return this.db.callFunctionJson<PercepcionCompletoResult>('ven_obtener_percepcion', [id]);
  }

  async listar(params: {
    idEmpresa?: number;
    fechaDesde?: string;
    fechaHasta?: string;
    idCliente?: number;
    pagina?: number;
    tamano?: number;
  }): Promise<PercepcionListResult> {
    return this.db.callFunctionJson<PercepcionListResult>('ven_listar_percepciones', [
      params.idEmpresa ?? null,
      params.fechaDesde ?? null,
      params.fechaHasta ?? null,
      params.idCliente ?? null,
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
  }): Promise<PercepcionCompletoResult> {
    return this.db.callFunctionJson<PercepcionCompletoResult>('ven_registrar_respuesta_sunat_percepcion', [
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
