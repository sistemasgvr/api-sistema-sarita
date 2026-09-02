-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_listar_garantias
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.682Z
DROP FUNCTION IF EXISTS fin_listar_garantias(p_buscar character varying, p_id_cliente integer, p_desde date, p_hasta date, p_estado character varying, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION fin_listar_garantias(p_buscar character varying DEFAULT NULL::character varying, p_id_cliente integer DEFAULT NULL::integer, p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date, p_estado character varying DEFAULT NULL::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
    v_id_estado_filtro INT;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_buscar := NULLIF(TRIM(p_buscar), '');

    IF p_estado IS NOT NULL AND UPPER(p_estado) IN ('ACTIVA', 'DEVUELTA') THEN
        SELECT glo.id INTO v_id_estado_filtro
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'EstadoGarantia' AND glo.nombre = UPPER(p_estado)
        LIMIT 1;
    END IF;

    WITH base AS (
        SELECT
            g.id, g.fecha,
            g.id_cliente,
            COALESCE(NULLIF(TRIM(c.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                     'Cliente #' || g.id_cliente) AS cliente,
            c.numero_documento AS documento_cliente,
            g.id_medio_pago, mp.nombre AS medio_pago,
            g.importe, g.observacion,
            g.fecha_reembolso,
            g.id_medio_reembolso, mr.nombre AS medio_reembolso,
            g.observacion_reembolso,
            g.id_estado, est.nombre AS estado_texto,
            g.fecha_creacion
        FROM fin_garantia g
        JOIN cli_clientes c ON c.id = g.id_cliente
        LEFT JOIN gen_lista_opciones mp  ON mp.id = g.id_medio_pago
        LEFT JOIN gen_lista_opciones mr  ON mr.id = g.id_medio_reembolso
        LEFT JOIN gen_lista_opciones est ON est.id = g.id_estado
        WHERE g.estado = 1
          AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
          AND (p_desde IS NULL OR g.fecha >= p_desde)
          AND (p_hasta IS NULL OR g.fecha <= p_hasta)
          AND (v_id_estado_filtro IS NULL OR g.id_estado = v_id_estado_filtro)
          AND (
                v_buscar IS NULL
                OR c.razon_social ILIKE '%' || v_buscar || '%'
                OR c.nombres ILIKE '%' || v_buscar || '%'
                OR c.apellido_paterno ILIKE '%' || v_buscar || '%'
                OR c.apellido_materno ILIKE '%' || v_buscar || '%'
                OR c.numero_documento ILIKE '%' || v_buscar || '%'
                OR g.observacion ILIKE '%' || v_buscar || '%'
                OR g.observacion_reembolso ILIKE '%' || v_buscar || '%'
              )
    ),
    total_count AS (SELECT COUNT(*) AS total FROM base),
    paginados AS (
        SELECT * FROM base
        ORDER BY fecha DESC, id DESC
        LIMIT p_limite OFFSET p_offset
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$function$
