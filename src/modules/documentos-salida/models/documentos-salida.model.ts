import { ConflictException, Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  ActualizarDocSalidaDetalleDto,
  ActualizarDocSalidaDto,
  AnularDocSalidaDto,
  ConvertirGreDto,
  CreateDocSalidaDetalleDto,
  CreateDocSalidaDto,
  CrearDesdeVentaDto,
  FiltroDocSalidaDto,
  FinalizarRecargaDto,
  RegistrarDireccionEntregaDto,
  SiguienteNumeroDocSalidaQueryDto,
  SeriesGreQueryDto,
  ActualizarTrasladoDto,
} from '../dto/documentos-salida.dto';
import type {
  DocSalidaEliminarDetalleResult,
  DocumentoSalidaCompletoResult,
  DocumentoSalidaListResult,
  EmpresaEmisora,
  GreIntentoRegistro,
  SerieGre,
} from '../interfaces/documento-salida.interface';

/** Con qué empresa y entorno del PSE se envió un intento (queda en doc_gre_intento). */
export interface ContextoIntentoGre {
  idEmpresa: number;
  rucEmisor: string;
  entorno: string | null;
  idEmpresaPse: number | null;
}

export interface IntentoGrePendiente {
  id: number;
  id_doc_salida: number;
  id_empresa: number | null;
  entorno: string | null;
  estado: string;
  ticket: string | null;
  consultas: number;
}

@Injectable()
export class DocumentosSalidaModel {
  constructor(
    private readonly db: DatabaseService,
  ) {}

  /** Reclamo duradero: la exclusión vive en PostgreSQL, incluso con varias APIs. */
  async iniciarIntentoGre(
    id: number,
    registro: unknown,
    payload: unknown,
    contexto: ContextoIntentoGre,
    idUsuario?: number,
  ) {
    const client = await this.db.getClient();
    try {
      await client.query('BEGIN');
      await client.query('SELECT id FROM doc_salida WHERE id = $1 FOR UPDATE', [id]);
      // Con el candado tomado, una segunda solicitud que esperó a la primera
      // ve su intento ya registrado: se le dice eso y no «la guía cambió».
      const abierto = await client.query(
        `SELECT 1 FROM doc_gre_intento WHERE id_doc_salida = $1 AND estado <> 'RECHAZADO' LIMIT 1`,
        [id],
      );
      if (abierto.rows.length > 0) {
        throw new ConflictException('Existe un envío en curso o pendiente de confirmar. Consulta su estado; no vuelvas a emitir.');
      }
      const { rows } = await client.query(
        `SELECT (doc_obtener_salida($1)::jsonb->'registro') = $2::jsonb AS vigente`,
        [id, JSON.stringify(registro)],
      );
      if (!rows[0]?.vigente) throw new ConflictException('La guía cambió. Recarga y verifica sus datos antes de emitir.');
      const attempt = await client.query<{ id: number }>(
        `INSERT INTO doc_gre_intento (
           id_doc_salida, estado, solicitud, documento, id_usuario,
           id_empresa, ruc_emisor, entorno, id_empresa_pse
         ) VALUES ($1, 'ENVIANDO', $2::jsonb, $3::jsonb, $4, $5, $6, $7, $8) RETURNING id`,
        [
          id, JSON.stringify(payload), JSON.stringify(registro), idUsuario ?? null,
          contexto.idEmpresa, contexto.rucEmisor, contexto.entorno, contexto.idEmpresaPse,
        ],
      );
      await client.query('COMMIT');
      return attempt.rows[0].id;
    } catch (error) {
      await client.query('ROLLBACK');
      if ((error as { code?: string }).code === '23505') {
        throw new ConflictException('Existe un envío en curso o pendiente de confirmar. Consulta su estado; no vuelvas a emitir.');
      }
      throw error;
    } finally { client.release(); }
  }

  async guardarResultadoIntentoGre(
    id: number,
    estado: string,
    respuesta: unknown,
    proximaConsulta: Date | null = null,
  ) {
    await this.db.query(
      `UPDATE doc_gre_intento
       SET estado = $2, respuesta = $3::jsonb, proxima_consulta = $4, actualizado = now()
       WHERE id = $1 AND estado NOT IN ('ACEPTADO', 'RECHAZADO')`,
      [id, estado, JSON.stringify(respuesta), proximaConsulta],
    );
  }

  /**
   * Cada consulta al PSE queda registrada contra el último intento; el estado
   * del intento solo avanza (nunca vuelve de ACEPTADO/RECHAZADO a pendiente).
   */
  async registrarConsultaGre(id: number, estado: string, respuesta: unknown, proximaConsulta: Date | null = null) {
    await this.db.query(
      `WITH intento AS (
         SELECT id FROM doc_gre_intento WHERE id_doc_salida = $1 ORDER BY id DESC LIMIT 1
       ), evento AS (
         INSERT INTO doc_gre_consulta (id_intento, respuesta)
         SELECT id, $3::jsonb FROM intento
       ) UPDATE doc_gre_intento
         SET estado = $2, consultas = consultas + 1, proxima_consulta = $4, actualizado = now()
         WHERE id IN (SELECT id FROM intento) AND estado NOT IN ('ACEPTADO', 'RECHAZADO')`,
      [id, estado, JSON.stringify(respuesta), proximaConsulta],
    );
  }

  async obtenerFuenteArchivosGre(id: number) {
    const { rows } = await this.db.query<{
      id: number; id_empresa: number; entorno: string | null;
      solicitud: Record<string, unknown>; respuesta: { xml?: string } | null;
      pdf_base64: string | null;
    }>(
      `SELECT i.id, i.id_empresa, i.entorno, i.solicitud, i.respuesta, a.pdf_base64
       FROM doc_gre_intento i LEFT JOIN doc_gre_archivo a ON a.id_intento = i.id
       WHERE i.id_doc_salida = $1 ORDER BY i.id DESC LIMIT 1`, [id],
    );
    return rows[0] ?? null;
  }

  async obtenerXmlHistoricoGre(id: number): Promise<string | null> {
    const { rows } = await this.db.query<{ xml_firmado: string | null }>(
      'SELECT xml_firmado FROM doc_salida WHERE id = $1 AND estado = 1', [id],
    );
    return rows[0]?.xml_firmado ?? null;
  }

  async guardarPdfGre(idIntento: number, pdfBase64: string) {
    await this.db.query(
      `INSERT INTO doc_gre_archivo (id_intento, pdf_base64) VALUES ($1, $2)
       ON CONFLICT (id_intento) DO NOTHING`, [idIntento, pdfBase64],
    );
  }

  async obtenerUltimoIntentoGre(id: number): Promise<IntentoGrePendiente | null> {
    const result = await this.db.query<IntentoGrePendiente>(
      `SELECT i.id, i.id_doc_salida, i.id_empresa, i.entorno, i.estado, i.consultas,
              NULLIF(TRIM(d.ticket_sunat), '') AS ticket
       FROM doc_gre_intento i JOIN doc_salida d ON d.id = i.id_doc_salida
       WHERE i.id_doc_salida = $1 ORDER BY i.id DESC LIMIT 1`,
      [id],
    );
    return result.rows[0] ?? null;
  }

  /**
   * Reclama intentos con ticket cuya próxima consulta ya venció. El reclamo
   * adelanta `proxima_consulta` en la misma sentencia (SKIP LOCKED) para que
   * el cron y el job HTTP, o dos APIs, no consulten el mismo ticket a la vez.
   */
  async listarIntentosGrePendientesConsulta(limite: number): Promise<IntentoGrePendiente[]> {
    const result = await this.db.query<IntentoGrePendiente>(
      `WITH reclamados AS (
         SELECT i.id
         FROM doc_gre_intento i
         JOIN doc_salida d ON d.id = i.id_doc_salida AND d.estado = 1
         JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
         WHERE i.estado IN ('PENDIENTE', 'POR_CONFIRMAR')
           AND NULLIF(TRIM(d.ticket_sunat), '') IS NOT NULL
           AND ec.nombre <> 'ANULADA'
           AND (i.proxima_consulta IS NULL OR i.proxima_consulta <= now())
         ORDER BY i.proxima_consulta NULLS FIRST, i.id
         LIMIT $1
         FOR UPDATE OF i SKIP LOCKED
       )
       UPDATE doc_gre_intento i
       SET proxima_consulta = now() + interval '2 minutes'
       FROM reclamados r, doc_salida d
       WHERE i.id = r.id AND d.id = i.id_doc_salida
       RETURNING i.id, i.id_doc_salida, i.id_empresa, i.entorno, i.estado, i.consultas,
                 NULLIF(TRIM(d.ticket_sunat), '') AS ticket`,
      [limite],
    );
    return result.rows;
  }

  async programarConsultaGre(idIntento: number, proximaConsulta: Date | null) {
    await this.db.query(
      `UPDATE doc_gre_intento SET proxima_consulta = $2, actualizado = now()
       WHERE id = $1 AND estado NOT IN ('ACEPTADO', 'RECHAZADO')`,
      [idIntento, proximaConsulta],
    );
  }

  /** Historial completo de intentos y consultas (sin secretos: solo respuestas del PSE). */
  async listarHistorialGre(id: number): Promise<GreIntentoRegistro[]> {
    const result = await this.db.query<GreIntentoRegistro>(
      `SELECT i.id, i.estado, i.entorno, i.id_empresa, i.ruc_emisor, i.consultas,
              i.proxima_consulta, i.creado, i.actualizado, i.respuesta,
              NULLIF(TRIM(d.ticket_sunat), '') AS ticket,
              COALESCE((
                SELECT json_agg(json_build_object('id', c.id, 'creado', c.creado, 'respuesta', c.respuesta) ORDER BY c.id)
                FROM doc_gre_consulta c WHERE c.id_intento = i.id
              ), '[]'::json) AS consultas_detalle
       FROM doc_gre_intento i JOIN doc_salida d ON d.id = i.id_doc_salida
       WHERE i.id_doc_salida = $1 ORDER BY i.id DESC`,
      [id],
    );
    return result.rows;
  }

  listar(filtros: FiltroDocSalidaDto) {
    return this.db.callFunctionJson<DocumentoSalidaListResult>('doc_listar_salidas', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idTipoOrden ?? null,
      filtros.idEstadoCiclo ?? null,
      filtros.idSucursal ?? null,
      filtros.idAlmacen ?? null,
      filtros.idCliente ?? null,
      filtros.emitidoSunat ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.codigoTipoOrden ?? null,
      filtros.sinActividadVigente ?? null,
      filtros.idProveedor ?? null,
      filtros.codigoEstadoCiclo ?? null,
    ]);
  }

  obtener(id: number) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_obtener_salida', [id]);
  }

  obtenerSiguienteNumero(query: SiguienteNumeroDocSalidaQueryDto) {
    return this.db.callFunctionJson<string>('doc_obtener_siguiente_numero', [
      query.idSucursal,
      query.fecha ?? null,
    ]);
  }

  listarSeriesGre(query: SeriesGreQueryDto) {
    return this.db.callFunctionJson<SerieGre[]>('doc_listar_series_gre', [
      query.idTipoGuiaRemision ?? null,
    ]);
  }

  crear(dto: CreateDocSalidaDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_crear_salida', [
      dto.codigoTipoOrden,
      dto.idSucursal,
      dto.idAlmacen,
      dto.idVenta ?? null,
      dto.idCliente ?? null,
      dto.idDestinatario ?? null,
      dto.idProveedor ?? null,
      dto.idDocSalidaOrigen ?? null,
      dto.fecha ?? null,
      dto.fechaTraslado ?? null,
      dto.observaciones ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.pesoBruto ?? null,
      dto.numeroBultos ?? null,
      dto.idAlmacenDestino ?? null,
      dto.idEmpresa ?? null,
    ]);
  }

  crearDesdeVenta(dto: CrearDesdeVentaDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_crear_desde_venta', [
      dto.idVenta,
      dto.idDestinatario ?? null,
      dto.fechaTraslado ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.idEmpresa ?? null,
    ]);
  }

  agregarDetalle(idDocSalida: number, dto: CreateDocSalidaDetalleDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_crear_salida_detalle', [
      idDocSalida,
      dto.idProducto ?? null,
      dto.idBalon ?? null,
      dto.cantidad,
      dto.descripcion ?? null,
      dto.idUnidadMedida ?? null,
      dto.glosa ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizarDetalle(idDetalle: number, dto: ActualizarDocSalidaDetalleDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_actualizar_salida_detalle', [
      idDetalle,
      dto.cantidad ?? null,
      dto.glosa ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: ActualizarDocSalidaDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_actualizar_salida', [
      id,
      dto.observaciones ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminarDetalle(idDetalle: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<DocSalidaEliminarDetalleResult>(
      'doc_eliminar_salida_detalle',
      [idDetalle, idUsuarioAuditoria ?? null],
    );
  }

  actualizarTraslado(id: number, dto: ActualizarTrasladoDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_actualizar_traslado', [
      id,
      dto.idMotivoTraslado ?? null,
      dto.idModalidadTraslado ?? null,
      dto.pesoBruto ?? null,
      dto.numeroBultos ?? null,
      dto.idUnidadMedida ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.idTipoGuiaRemision ?? null,
      dto.idChofer ?? null,
      dto.idVehiculo ?? null,
      dto.idTransportista ?? null,
      dto.fechaTraslado ?? null,
    ]);
  }

  generar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_generar_salida', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  convertirAGre(id: number, dto: ConvertirGreDto) {
    const params = [
      id,
      dto.idTipoGuiaRemision ?? null,
      dto.serie,
      dto.idMotivoTraslado ?? null,
      dto.idModalidadTraslado ?? null,
      dto.idTransportista ?? null,
      dto.idChofer ?? null,
      dto.idVehiculo ?? null,
      dto.idUnidadMedida ?? null,
      dto.pesoBruto ?? null,
      dto.numeroBultos ?? null,
      dto.direccionOrigen ?? null,
      dto.idDistritoOrigen ?? null,
      dto.direccionLlegada ?? null,
      dto.idDistritoLlegada ?? null,
      dto.fechaTraslado ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.idEmpresa,
      dto.fechaEmisionGre,
    ];
    return this.db.query<{ result: DocumentoSalidaCompletoResult }>(
      `SELECT public.doc_convertir_a_gre(
        $1::integer, $2::integer, $3::varchar, $4::integer, $5::integer,
        $6::integer, $7::integer, $8::integer, $9::integer, $10::numeric,
        $11::integer, $12::varchar, $13::integer, $14::varchar, $15::integer,
        $16::date, $17::integer, p_id_empresa => $18::integer, p_fecha_emision_gre => $19::date
      ) AS result`, params,
    ).then(({ rows }) => rows[0].result);
  }

  registrarDireccionEntrega(id: number, dto: RegistrarDireccionEntregaDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_registrar_direccion_entrega', [
      id,
      dto.direccionEntrega ?? null,
      dto.referenciaEntrega ?? null,
      dto.latitud ?? null,
      dto.longitud ?? null,
      dto.idDistritoEntrega ?? null,
      dto.idDireccionCliente ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.guardarEnCliente ?? true,
    ]);
  }

  anular(id: number, dto: AnularDocSalidaDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_anular_salida', [
      id,
      dto.motivo ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  finalizarRecarga(id: number, dto: FinalizarRecargaDto) {
    return this.db.callFunctionJson<{
      error: string | null;
      registro: { id_recarga_planta: number; retorno_fisico: boolean } | null;
    }>(
      'bal_finalizar_recarga_planta',
      [
        id,
        dto.idComprobanteCompra ?? null,
        dto.fechaLlegadaAlmacen,
        dto.idAlmacen,
        dto.idProveedor ?? null,
        dto.guardarBalonesAlmacen ?? false,
        dto.lote ?? null,
        dto.fechaVencimientoLote ?? null,
        dto.fechaPruebaHidrostatica ?? null,
        dto.idUsuarioAuditoria ?? null,
        dto.idLoteProtocolo ?? null,
      ],
    );
  }

  registrarRespuestaSunat(
    id: number,
    params: {
      codigoEstadoSunat: string;
      ticketSunat?: string | null;
      hashDocumento?: string | null;
      xmlFirmado?: string | null;
      cdrRespuesta?: string | null;
      idUsuarioAuditoria?: number;
    },
  ) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_registrar_respuesta_sunat', [
      id,
      params.codigoEstadoSunat,
      params.ticketSunat ?? null,
      params.hashDocumento ?? null,
      params.xmlFirmado ?? null,
      params.cdrRespuesta ?? null,
      params.idUsuarioAuditoria ?? null,
    ]);
  }

  /** Empresa emisora con su domicilio fiscal (distrito → ubigeo) para el payload. */
  async obtenerEmpresaEmisora(idEmpresa: number): Promise<EmpresaEmisora | null> {
    const result = await this.db.query<EmpresaEmisora>(
      `SELECT e.id, e.ruc, e.razon_social, e.nombre_comercial, e.direccion,
              e.id_distrito, dist.codigo_ubigeo, dist.nombre AS nombre_distrito,
              prov.nombre AS nombre_provincia, dep.nombre AS nombre_departamento
       FROM gen_empresa e
       LEFT JOIN gen_distrito dist ON dist.id = e.id_distrito
       LEFT JOIN gen_provincia prov ON prov.id = dist.id_provincia
       LEFT JOIN gen_departamento dep ON dep.id = prov.id_departamento
       WHERE e.estado = 1 AND e.id = $1`, [idEmpresa],
    );
    return result.rows[0] ?? null;
  }
}
