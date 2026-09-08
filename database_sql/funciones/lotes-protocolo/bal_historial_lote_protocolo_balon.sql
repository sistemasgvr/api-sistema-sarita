-- Function: bal_historial_lote_protocolo_balon
-- Fase 5 — historial de fichas ICP por cilindro (apunte 2.a.ii).
--
-- El historial no se guarda aparte: se deriva de las recargas que referencian
-- una ficha. Hay dos orígenes porque la Fase 2 movió la recarga en planta
-- externa a doc_salida y la de mostrador siguió en bal_movimiento_recarga.
DROP FUNCTION IF EXISTS bal_historial_lote_protocolo_balon(p_id_balon integer, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION bal_historial_lote_protocolo_balon(p_id_balon integer, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_vigente JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1) THEN
        RETURN json_build_object(
            'error', 'Cilindro no encontrado',
            'registros', '[]'::JSON,
            'total', 0,
            'vigente', NULL
        );
    END IF;

    WITH hist AS (
        SELECT
            'PLANTA_EXTERNA'::VARCHAR AS origen,
            d.id                      AS id_documento,
            d.numero                  AS numero_documento,
            COALESCE(d.fecha_llegada_almacen, d.fecha_retorno, d.fecha) AS fecha,
            d.id_lote_protocolo,
            d.id_almacen,
            d.id_proveedor
        FROM doc_salida d
        JOIN doc_salida_detalle dd ON dd.id_doc_salida = d.id AND dd.estado = 1
        WHERE d.estado = 1
          AND d.id_lote_protocolo IS NOT NULL
          AND dd.id_balon = p_id_balon
        UNION
        SELECT
            'MOVIMIENTO_RECARGA'::VARCHAR,
            r.id,
            NULL::VARCHAR,
            COALESCE(r.fecha_llegada_almacen, r.fecha_salida_almacen),
            r.id_lote_protocolo,
            r.id_almacen,
            r.id_proveedor
        FROM bal_movimiento_recarga r
        WHERE r.estado = 1
          AND r.id_lote_protocolo IS NOT NULL
          AND r.id_balon = p_id_balon
    ),
    pagina AS (
        SELECT
            h.origen,
            h.id_documento,
            h.numero_documento,
            h.fecha,
            h.id_lote_protocolo,
            lp.numero_lote,
            lp.numero_protocolo,
            lp.fecha_vencimiento,
            (lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE) AS vencido,
            lp.valoracion_o2_pct,
            lp.id_archivo_pdf,
            ar.ruta AS ruta_archivo_pdf,
            h.id_almacen,
            a.nombre AS nombre_almacen,
            h.id_proveedor,
            COALESCE(
                NULLIF(TRIM(pv.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno, pv.apellido_materno)), ''),
                pv.numero_documento
            ) AS nombre_proveedor,
            (b.id_lote_protocolo_vigente = h.id_lote_protocolo) AS es_vigente
        FROM hist h
        JOIN bal_lote_protocolo lp ON lp.id = h.id_lote_protocolo
        JOIN bal_balon b ON b.id = p_id_balon
        LEFT JOIN gen_archivo ar ON ar.id = lp.id_archivo_pdf
        LEFT JOIN gen_almacen a ON a.id = h.id_almacen
        LEFT JOIN cli_clientes pv ON pv.id = h.id_proveedor
        ORDER BY h.fecha DESC NULLS LAST, h.id_documento DESC
        LIMIT GREATEST(COALESCE(p_limite, 50), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    )
    SELECT
        COALESCE(
            json_agg(row_to_json(p) ORDER BY p.fecha DESC NULLS LAST, p.id_documento DESC),
            '[]'::JSON
        ),
        (SELECT COUNT(*) FROM hist)
    INTO v_registros, v_total
    FROM pagina p;

    SELECT row_to_json(v) INTO v_vigente
    FROM (
        SELECT
            lp.id,
            lp.numero_lote,
            lp.numero_protocolo,
            lp.fecha_vencimiento,
            (lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE) AS vencido,
            lp.valoracion_o2_pct,
            lp.id_archivo_pdf,
            ar.ruta AS ruta_archivo_pdf
        FROM bal_balon b
        JOIN bal_lote_protocolo lp ON lp.id = b.id_lote_protocolo_vigente AND lp.estado = 1
        LEFT JOIN gen_archivo ar ON ar.id = lp.id_archivo_pdf
        WHERE b.id = p_id_balon
    ) v;

    RETURN json_build_object(
        'error', NULL,
        'registros', COALESCE(v_registros, '[]'::JSON),
        'total', COALESCE(v_total, 0),
        'vigente', v_vigente
    );
END;
$function$;
