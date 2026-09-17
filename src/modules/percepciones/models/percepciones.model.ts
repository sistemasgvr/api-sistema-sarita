import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import type {
  ComprobanteElegiblePercepcion,
  PercepcionCompletoResult,
  PercepcionDetalleSql,
  PercepcionListResult,
} from '../interfaces/percepcion.interface';

@Injectable()
export class PercepcionesModel {
  constructor(private readonly db: DatabaseService) {}

  /**
   * Facturas y boletas (01/03) en soles (la lista Moneda usa NUEVOS_SOLES y el POS
   * deja id_moneda nulo, que también es soles), aceptadas por SUNAT, no anuladas y sin
   * percepción vigente: los únicos comprobantes sobre los que se puede percibir.
   * Solo clientes con documento (la percepción los identifica ante SUNAT).
   */
  private static readonly SQL_ELEGIBLES = `
    SELECT c.id, c.serie, c.numero, c.fecha::text AS fecha, TRIM(tc.descripcion) AS tipo_doc,
           tc.nombre AS nombre_tipo_comprobante, c.total_importe AS total,
           CASE WHEN m.id IS NULL OR m.nombre IN ('PEN', 'NUEVOS_SOLES') THEN 'PEN' ELSE m.nombre END AS moneda,
           c.id_cliente,
           COALESCE(NULLIF(TRIM(cl.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno)), '')) AS nombre_cliente,
           cl.numero_documento AS documento_cliente,
           es.nombre AS nombre_estado_sunat,
           EXISTS (
             SELECT 1 FROM ven_percepcion_detalle d JOIN ven_percepcion p ON p.id = d.id_percepcion
             WHERE d.id_comprobante = c.id AND d.estado = 1 AND p.estado = 1
           ) AS con_percepcion
    FROM ven_comprobante c
    JOIN gen_lista_opciones tc ON tc.id = c.id_tipo_comprobante
    LEFT JOIN gen_lista_opciones m ON m.id = c.id_moneda
    LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
    LEFT JOIN cli_clientes cl ON cl.id = c.id_cliente`;

  async listarComprobantesElegibles(params: { idCliente?: number; buscar?: string; limite?: number }) {
    const buscar = (params.buscar ?? '').trim().toLowerCase().replace(/\s+/g, '');
    const result = await this.db.query<ComprobanteElegiblePercepcion>(
      `${PercepcionesModel.SQL_ELEGIBLES}
       WHERE c.estado = 1
         AND TRIM(tc.descripcion) IN ('01', '03')
         AND (m.id IS NULL OR m.nombre IN ('PEN', 'NUEVOS_SOLES'))
         AND es.nombre = 'ACEPTADO'
         AND NULLIF(TRIM(cl.numero_documento), '') IS NOT NULL AND TRIM(cl.numero_documento) !~ '^0+$'
         AND ($1::integer IS NULL OR c.id_cliente = $1)
         AND ($2 = '' OR LOWER(c.serie || '-' || c.numero) LIKE '%' || $2 || '%'
              OR LOWER(REPLACE(COALESCE(cl.razon_social, CONCAT_WS(' ', cl.nombres, cl.apellido_paterno)), ' ', '')) LIKE '%' || $2 || '%')
         AND NOT EXISTS (
           SELECT 1 FROM ven_percepcion_detalle d JOIN ven_percepcion p ON p.id = d.id_percepcion
           WHERE d.id_comprobante = c.id AND d.estado = 1 AND p.estado = 1
         )
       ORDER BY c.fecha DESC, c.id DESC
       LIMIT $3`,
      [params.idCliente ?? null, buscar, params.limite ?? 20],
    );
    return result.rows;
  }

  /** Los comprobantes elegidos, con todo lo que la validación necesita. */
  async obtenerComprobantes(ids: number[]) {
    if (ids.length === 0) return [];
    const result = await this.db.query<ComprobanteElegiblePercepcion & { estado: number }>(
      `${PercepcionesModel.SQL_ELEGIBLES.replace('SELECT c.id,', 'SELECT c.estado, c.id,')}
       WHERE c.id = ANY($1::integer[])`,
      [ids],
    );
    return result.rows;
  }

  async crear(params: {
    serie: string;
    fechaEmision: string;
    idEmpresa: number;
    idCliente: number;
    idSucursal?: number | null;
    regimen: string;
    tasa: number;
    baseImponible: number;
    montoPercibido: number;
    montoCobrado: number;
    observacion?: string;
    detalles: PercepcionDetalleSql[];
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
      JSON.stringify(params.detalles),
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

  async obtenerCatalogos() {
    const [regimenesPercepcion, estadosSunat] = await Promise.all([
      this.db.query<{ id: number; nombre: string; descripcion: string | null }>(
        `SELECT o.id, o.nombre, o.descripcion
         FROM gen_lista_opciones o
         INNER JOIN gen_lista l ON o.id_lista = l.id
         WHERE l.nombre = 'RegimenPercepcion' AND o.estado = 1
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
      regimenesPercepcion: regimenesPercepcion.rows,
      estadosSunat: estadosSunat.rows,
    };
  }
}
