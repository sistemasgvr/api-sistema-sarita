-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_pendientes_recojo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.947Z
DROP FUNCTION IF EXISTS bal_listar_pendientes_recojo(p_busqueda character varying, p_limite integer, p_offset integer, p_id_cliente integer, p_tipo_origen character varying, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION bal_listar_pendientes_recojo(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_cliente integer DEFAULT NULL::integer, p_tipo_origen character varying DEFAULT NULL::character varying, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_rows JSON;
    v_total BIGINT;
    v_tipo VARCHAR := NULLIF(UPPER(TRIM(p_tipo_origen)), '');
BEGIN
    SET TIME ZONE 'America/Lima';

    IF v_tipo IS NOT NULL AND v_tipo NOT IN ('PRESTAMO', 'ALQUILER') THEN
        RETURN json_build_object('registros', '[]'::JSON, 'total', 0);
    END IF;

    WITH pendientes AS (
        SELECT
            'PRESTAMO'::VARCHAR AS origen,
            p.id AS id_origen,
            p.numero_prestamo AS numero_origen,
            pd.id AS id_detalle,
            'CILINDRO'::VARCHAR AS tipo_item,
            p.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            pd.id_balon,
            b.codigo_balon,
            pd.fecha_vencimiento AS fecha_retorno,
            CURRENT_DATE - pd.fecha_vencimiento AS dias_pendientes,
            EXISTS (
                SELECT 1
                FROM bal_recojo_detalle rd
                JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
                JOIN gen_lista_opciones e ON e.id = r.id_estado
                WHERE rd.id_prestamo_detalle = pd.id
                  AND rd.estado = 1
                  AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
            ) AS tiene_recojo_programado
        FROM bal_prestamo_detalle pd
        JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
        JOIN gen_lista_opciones ep ON ep.id = p.id_estado AND ep.nombre = 'ACTIVO'
        LEFT JOIN cli_clientes c ON c.id = p.id_cliente
        LEFT JOIN bal_balon b ON b.id = pd.id_balon
        WHERE pd.estado = 1
          AND pd.fecha_devolucion IS NULL

        UNION ALL

        -- Alquiler activo con regulador/accesorio pendiente (con o sin cilindros)
        SELECT
            'ALQUILER'::VARCHAR,
            a.id,
            a.numero_alquiler,
            0 AS id_detalle,
            'REGULADOR'::VARCHAR,
            a.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno)), ''),
                c.numero_documento
            ),
            NULL::INTEGER AS id_balon,
            COALESCE(
                NULLIF(TRIM(CONCAT_WS(
                    ' — ',
                    NULLIF(TRIM(COALESCE(pr.codigo, ps.codigo)), ''),
                    NULLIF(TRIM(COALESCE(pr.nombre, ps.nombre)), '')
                )), ''),
                'Regulador / accesorio'
            ) AS codigo_balon,
            a.fecha_fin_pactada,
            CURRENT_DATE - a.fecha_fin_pactada,
            EXISTS (
                SELECT 1
                FROM bal_recojo r
                JOIN gen_lista_opciones e ON e.id = r.id_estado
                WHERE r.id_alquiler = a.id
                  AND r.estado = 1
                  AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
                  AND NOT EXISTS (
                      SELECT 1
                      FROM bal_recojo_detalle rd
                      WHERE rd.id_recojo = r.id
                        AND rd.estado = 1
                        AND (
                            rd.id_prestamo_detalle IS NOT NULL
                            OR rd.id_alquiler_detalle IS NOT NULL
                        )
                  )
            )
        FROM bal_alquiler a
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado AND ea.nombre = 'ACTIVO'
        LEFT JOIN cli_clientes c ON c.id = a.id_cliente
        LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
        LEFT JOIN pro_producto ps ON ps.id = a.id_producto_stock
        WHERE a.estado = 1
          AND a.fecha_fin_real IS NULL
          AND a.fecha_devolucion_regulador IS NULL
          AND COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
    ),
    filtrados AS (
        SELECT *
        FROM pendientes x
        WHERE (v_tipo IS NULL OR x.origen = v_tipo)
          AND (p_id_cliente IS NULL OR x.id_cliente = p_id_cliente)
          AND (p_fecha_hasta IS NULL OR x.fecha_retorno <= p_fecha_hasta)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(x.numero_origen, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(x.nombre_cliente, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(x.codigo_balon, ''), p_busqueda)
          )
    ),
    pagina AS (
        SELECT
            origen,
            id_origen,
            numero_origen,
            id_detalle,
            tipo_item,
            id_cliente,
            nombre_cliente,
            id_balon,
            codigo_balon,
            fecha_retorno,
            dias_pendientes,
            tiene_recojo_programado
        FROM filtrados
        ORDER BY fecha_retorno ASC NULLS LAST, origen, id_origen, id_detalle
        LIMIT p_limite OFFSET COALESCE(p_offset, 0)
    )
    SELECT
        (SELECT COUNT(*)::BIGINT FROM filtrados),
        COALESCE(
            (
                SELECT json_agg(row_to_json(p) ORDER BY p.fecha_retorno ASC NULLS LAST, p.origen, p.id_origen, p.id_detalle)
                FROM pagina p
            ),
            '[]'::JSON
        )
    INTO v_total, v_rows;

    RETURN json_build_object('registros', COALESCE(v_rows, '[]'::JSON), 'total', COALESCE(v_total, 0));
END;
$function$;
