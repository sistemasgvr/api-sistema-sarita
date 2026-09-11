-- Function: bal_reporte_alquileres_antiguedad
-- Reescrita por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- el alquiler es solo del regulador/accesorio (el cilindro va por préstamo y
-- bal_alquiler_detalle se eliminó). El reporte es una fila por alquiler con
-- accesorio pendiente de devolución; los días se cuentan desde fecha_inicio
-- y el atraso desde fecha_fin_pactada.
--
-- Firma: se retira p_excluir_bajas (era un filtro sobre el estado del cilindro).

DROP FUNCTION IF EXISTS bal_reporte_alquileres_antiguedad(p_busqueda character varying, p_limite integer, p_offset integer, p_id_cliente integer, p_rango_dias character varying, p_excluir_bajas boolean, p_solo_pendientes boolean);
DROP FUNCTION IF EXISTS bal_reporte_alquileres_antiguedad(p_busqueda character varying, p_limite integer, p_offset integer, p_id_cliente integer, p_rango_dias character varying, p_solo_pendientes boolean);

CREATE OR REPLACE FUNCTION bal_reporte_alquileres_antiguedad(
    p_busqueda character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 50,
    p_offset integer DEFAULT 0,
    p_id_cliente integer DEFAULT NULL::integer,
    p_rango_dias character varying DEFAULT NULL::character varying,
    p_solo_pendientes boolean DEFAULT true
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH base AS (
        SELECT
            a.id AS id_alquiler,
            a.numero_alquiler,
            a.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            a.id_almacen,
            alm.nombre AS nombre_almacen,
            COALESCE(a.id_producto_regulador, a.id_producto_stock) AS id_producto,
            COALESCE(pr.nombre, ps.nombre) AS nombre_producto,
            COALESCE(pr.codigo, ps.codigo) AS codigo_producto,
            ea.nombre AS nombre_estado,
            a.dias_periodo,
            a.tarifa_diaria,
            a.fecha_inicio AS fecha_inicio_alquiler,
            a.fecha_fin_pactada,
            a.fecha_devolucion_regulador AS fecha_devolucion,
            cr.nombre AS nombre_condicion_regulador,
            CASE
                WHEN a.fecha_devolucion_regulador IS NOT NULL THEN NULL
                ELSE (CURRENT_DATE - a.fecha_inicio)::INTEGER
            END AS dias_en_alquiler,
            CASE
                WHEN a.fecha_devolucion_regulador IS NOT NULL THEN NULL
                WHEN a.fecha_fin_pactada IS NULL THEN NULL
                ELSE GREATEST((CURRENT_DATE - a.fecha_fin_pactada)::INTEGER, 0)
            END AS dias_atraso,
            CASE
                WHEN a.fecha_devolucion_regulador IS NOT NULL THEN 'DEVUELTO'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 180 THEN 'CRITICO_180'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 90 THEN 'SEGUIMIENTO_90_180'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 30 THEN 'ATENCION_30_90'
                ELSE 'RECIENTE_0_30'
            END AS rango_antiguedad
        FROM bal_alquiler a
        LEFT JOIN cli_clientes c ON c.id = a.id_cliente
        LEFT JOIN gen_almacen alm ON alm.id = a.id_almacen
        LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
        LEFT JOIN pro_producto ps ON ps.id = a.id_producto_stock
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado
        LEFT JOIN gen_lista_opciones cr ON cr.id = a.id_condicion_regulador
        WHERE a.estado = 1
          AND COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
          AND a.fecha_inicio IS NOT NULL
          AND (p_solo_pendientes = FALSE OR a.fecha_devolucion_regulador IS NULL)
          AND (p_id_cliente IS NULL OR a.id_cliente = p_id_cliente)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(a.numero_alquiler, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.nombre, ps.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.codigo, ps.codigo, ''), p_busqueda)
          )
    ),
    filtrado AS (
        SELECT *
        FROM base
        WHERE (
            p_rango_dias IS NULL
            OR p_rango_dias = ''
            OR rango_antiguedad = p_rango_dias
        )
    ),
    agregado AS (
        SELECT
            (SELECT COUNT(*) FROM filtrado) AS total,
            (
                SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
                FROM (
                    SELECT *
                    FROM filtrado
                    ORDER BY
                        CASE WHEN dias_en_alquiler IS NULL THEN 1 ELSE 0 END,
                        dias_atraso DESC NULLS LAST,
                        dias_en_alquiler DESC NULLS LAST,
                        nombre_cliente ASC NULLS LAST,
                        numero_alquiler ASC NULLS LAST
                    LIMIT GREATEST(COALESCE(p_limite, 50), 1)
                    OFFSET GREATEST(COALESCE(p_offset, 0), 0)
                ) t
            ) AS registros,
            (
                SELECT json_build_object(
                    'total_pendientes', COUNT(*) FILTER (WHERE rango_antiguedad <> 'DEVUELTO'),
                    'reciente_0_30', COUNT(*) FILTER (WHERE rango_antiguedad = 'RECIENTE_0_30'),
                    'atencion_30_90', COUNT(*) FILTER (WHERE rango_antiguedad = 'ATENCION_30_90'),
                    'seguimiento_90_180', COUNT(*) FILTER (WHERE rango_antiguedad = 'SEGUIMIENTO_90_180'),
                    'critico_180', COUNT(*) FILTER (WHERE rango_antiguedad = 'CRITICO_180')
                )
                FROM base
            ) AS resumen
    )
    SELECT ag.total, ag.registros, ag.resumen
    INTO v_total, v_registros, v_resumen
    FROM agregado ag;

    RETURN json_build_object(
        'registros', COALESCE(v_registros, '[]'::JSON),
        'total', COALESCE(v_total, 0),
        'resumen', COALESCE(
            v_resumen,
            json_build_object(
                'total_pendientes', 0,
                'reciente_0_30', 0,
                'atencion_30_90', 0,
                'seguimiento_90_180', 0,
                'critico_180', 0
            )
        )
    );
END;
$function$;
