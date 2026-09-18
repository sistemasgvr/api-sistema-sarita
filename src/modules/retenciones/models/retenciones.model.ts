import { Injectable } from '@nestjs/common';
import {
  normalizarBusqueda,
  sqlCoincideBusqueda,
  type SerieTributo,
} from '../../../common/helpers/tributo-busqueda.helper';
import { DatabaseService } from '../../../database/database.service';
import type {
  CompraElegibleRetencion,
  RetencionCompletoResult,
  RetencionDetalleSql,
  RetencionListResult,
} from '../interfaces/retencion.interface';

@Injectable()
export class RetencionesModel {
  constructor(private readonly db: DatabaseService) {}

  /**
   * Compras con factura del proveedor (serie y número), en soles, no anuladas,
   * de proveedor con RUC y sin retención vigente: sobre esas se retiene al pagar.
   */
  private static readonly SQL_COINCIDE = sqlCoincideBusqueda('c', 'pr');

  private static readonly SQL_ELEGIBLES = `
    SELECT c.id, c.serie, c.numero, c.fecha::text AS fecha, TRIM(tc.descripcion) AS tipo_doc,
           tc.nombre AS nombre_tipo_comprobante, c.total_importe AS total,
           CASE WHEN m.id IS NULL OR m.nombre IN ('PEN', 'NUEVOS_SOLES') THEN 'PEN' ELSE m.nombre END AS moneda,
           c.id_proveedor, c.id_sucursal,
           COALESCE(NULLIF(TRIM(pr.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', pr.nombres, pr.apellido_paterno, pr.apellido_materno)), '')) AS nombre_proveedor,
           pr.numero_documento AS documento_proveedor,
           EXISTS (
             SELECT 1 FROM com_retencion_detalle d JOIN com_retencion r ON r.id = d.id_retencion
             WHERE d.id_compra = c.id AND d.estado = 1 AND r.estado = 1
           ) AS con_retencion
    FROM com_comprobante_compra c
    LEFT JOIN gen_lista_opciones tc ON tc.id = c.id_tipo_comprobante
    LEFT JOIN gen_lista_opciones m ON m.id = c.id_moneda
    LEFT JOIN cli_clientes pr ON pr.id = c.id_proveedor`;

  async listarComprasElegibles(params: { idProveedor?: number; buscar?: string; limite?: number }) {
    const buscar = normalizarBusqueda(params.buscar);
    const result = await this.db.query<CompraElegibleRetencion>(
      `${RetencionesModel.SQL_ELEGIBLES}
       WHERE c.estado = 1
         AND NULLIF(TRIM(c.serie), '') IS NOT NULL AND NULLIF(TRIM(c.numero), '') IS NOT NULL
         AND TRIM(tc.descripcion) IN ('01', '03')
         AND (m.id IS NULL OR m.nombre IN ('PEN', 'NUEVOS_SOLES'))
         AND pr.numero_documento ~ '^[0-9]{11}$'
         AND ($1::integer IS NULL OR c.id_proveedor = $1)
         AND ($2 = '' OR ${RetencionesModel.SQL_COINCIDE})
         AND NOT EXISTS (
           SELECT 1 FROM com_retencion_detalle d JOIN com_retencion r ON r.id = d.id_retencion
           WHERE d.id_compra = c.id AND d.estado = 1 AND r.estado = 1
         )
       ORDER BY c.fecha DESC, c.id DESC
       LIMIT $3`,
      [params.idProveedor ?? null, buscar, params.limite ?? 20],
    );
    return result.rows;
  }

  /** Series de retención ya usadas por la empresa, con su siguiente correlativo. */
  async listarSeries(idEmpresa?: number): Promise<SerieTributo[]> {
    return this.db.callFunctionJson<SerieTributo[]>('com_listar_series_retencion', [idEmpresa ?? null]);
  }

  /** Las compras elegidas, con todo lo que la validación necesita. */
  async obtenerCompras(ids: number[]) {
    if (ids.length === 0) return [];
    const result = await this.db.query<CompraElegibleRetencion & { estado: number }>(
      `${RetencionesModel.SQL_ELEGIBLES.replace('SELECT c.id,', 'SELECT c.estado, c.id,')}
       WHERE c.id = ANY($1::integer[])`,
      [ids],
    );
    return result.rows;
  }

  async crear(params: {
    serie: string;
    fechaEmision: string;
    idEmpresa: number;
    idProveedor: number;
    idSucursal?: number | null;
    regimen: string;
    tasa: number;
    baseImponible: number;
    montoRetenido: number;
    montoPagado: number;
    observacion?: string;
    detalles: RetencionDetalleSql[];
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
      JSON.stringify(params.detalles),
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

  async obtenerCatalogos() {
    const [regimenesRetencion, tasasRetencion, estadosSunat] = await Promise.all([
      this.db.query<{ id: number; nombre: string; descripcion: string | null }>(
        `SELECT o.id, o.nombre, o.descripcion
         FROM gen_lista_opciones o
         INNER JOIN gen_lista l ON o.id_lista = l.id
         WHERE l.nombre = 'RegimenRetencion' AND o.estado = 1
         ORDER BY o.descripcion, o.id`,
      ),
      // `descripcion` es el código del régimen al que aplica la tasa.
      this.db.query<{ id: number; nombre: string; descripcion: string | null }>(
        `SELECT o.id, o.nombre, o.descripcion
         FROM gen_lista_opciones o
         INNER JOIN gen_lista l ON o.id_lista = l.id
         WHERE l.nombre = 'TasaRetencion' AND o.estado = 1
         ORDER BY o.descripcion, o.id`,
      ),
      this.db.query<{ id: number; nombre: string; descripcion: string | null }>(
        `SELECT o.id, o.nombre, o.descripcion
         FROM gen_lista_opciones o
         INNER JOIN gen_lista l ON o.id_lista = l.id
         WHERE l.nombre = 'EstadoSunat' AND o.estado = 1
         ORDER BY o.id`,
      ),
    ]);

    return {
      regimenesRetencion: regimenesRetencion.rows,
      tasasRetencion: tasasRetencion.rows,
      estadosSunat: estadosSunat.rows,
    };
  }
}
