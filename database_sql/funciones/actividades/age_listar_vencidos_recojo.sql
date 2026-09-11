-- Function: age_listar_vencidos_recojo
-- Synced from migracion 20260908_age_recojo_vencidos_fk.sql
--
-- Actualizada por database_sql/migraciones/20260910_age_custodia_recojo_candado.sql:
-- además de la actividad RECOJO vigente, se excluyen los orígenes con una
-- visita viva en bal_recojo. La lista alimenta el botón de crear actividad de
-- recojo, que ahora rechaza esos orígenes (candado de consistencia):
-- ofrecerlos era ofrecer un error.

DROP FUNCTION IF EXISTS age_listar_vencidos_recojo(character varying, integer, integer);

CREATE OR REPLACE FUNCTION age_listar_vencidos_recojo(
    p_busqueda character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 30,
    p_offset integer DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_busqueda VARCHAR := LOWER(TRIM(COALESCE(p_busqueda, '')));
    v_rows JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH vigentes AS (
        SELECT a.id_prestamo, a.id_alquiler
        FROM age_actividad a
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.estado = 1
          AND ta.nombre = 'RECOJO'
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
    ),
    visitas AS (
        SELECT r.id_prestamo, r.id_alquiler
        FROM bal_recojo r
        JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.estado = 1
          AND UPPER(TRIM(er.nombre)) IN ('PROGRAMADO', 'EN_RUTA')
    ),
    base AS (
        SELECT
            'PRESTAMO'::VARCHAR AS origen,
            p.id AS id_origen,
            p.numero_prestamo AS numero,
            p.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            p.fecha_retorno_pactada AS fecha_pactada,
            (CURRENT_DATE - p.fecha_retorno_pactada)::INTEGER AS dias_vencido,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_prestamo_detalle pd
                WHERE pd.id_prestamo = p.id
                  AND pd.estado = 1
                  AND pd.fecha_devolucion IS NULL
                  AND pd.id_balon IS NOT NULL
            ) AS cilindros_pendientes,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_prestamo = p.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ) AS garantias_activas,
            FALSE AS regulador_pendiente
        FROM bal_prestamo p
        LEFT JOIN cli_clientes c ON c.id = p.id_cliente
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        WHERE p.estado = 1
          AND p.fecha_retorno_real IS NULL
          AND p.fecha_retorno_pactada IS NOT NULL
          AND p.fecha_retorno_pactada < CURRENT_DATE
          AND COALESCE(ep.nombre, 'ACTIVO') = 'ACTIVO'
          AND EXISTS (
              SELECT 1
              FROM bal_prestamo_detalle pd
              WHERE pd.id_prestamo = p.id
                AND pd.estado = 1
                AND pd.fecha_devolucion IS NULL
                AND pd.id_balon IS NOT NULL
          )
          AND NOT EXISTS (SELECT 1 FROM vigentes v WHERE v.id_prestamo = p.id)
          AND NOT EXISTS (SELECT 1 FROM visitas vi WHERE vi.id_prestamo = p.id)

        UNION ALL

        SELECT
            'ALQUILER'::VARCHAR,
            a.id,
            a.numero_alquiler,
            a.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ),
            a.fecha_fin_pactada,
            (CURRENT_DATE - a.fecha_fin_pactada)::INTEGER,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_alquiler_detalle ad
                WHERE ad.id_alquiler = a.id
                  AND ad.estado = 1
                  AND ad.fecha_devolucion IS NULL
                  AND ad.id_balon IS NOT NULL
            ),
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_alquiler = a.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ),
            (
                a.id_producto_regulador IS NOT NULL
                AND a.fecha_devolucion_regulador IS NULL
            )
        FROM bal_alquiler a
        LEFT JOIN cli_clientes c ON c.id = a.id_cliente
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado
        WHERE a.estado = 1
          AND a.fecha_fin_real IS NULL
          AND a.fecha_fin_pactada IS NOT NULL
          AND a.fecha_fin_pactada < CURRENT_DATE
          AND COALESCE(ea.nombre, 'ACTIVO') = 'ACTIVO'
          AND (
              EXISTS (
                  SELECT 1
                  FROM bal_alquiler_detalle ad
                  WHERE ad.id_alquiler = a.id
                    AND ad.estado = 1
                    AND ad.fecha_devolucion IS NULL
                    AND ad.id_balon IS NOT NULL
              )
              OR (
                  a.id_producto_regulador IS NOT NULL
                  AND a.fecha_devolucion_regulador IS NULL
              )
          )
          AND NOT EXISTS (SELECT 1 FROM vigentes v WHERE v.id_alquiler = a.id)
          AND NOT EXISTS (SELECT 1 FROM visitas vi WHERE vi.id_alquiler = a.id)
    ),
    filtrado AS (
        SELECT *
        FROM base
        WHERE v_busqueda = ''
           OR LOWER(COALESCE(numero, '')) LIKE '%' || v_busqueda || '%'
           OR LOWER(COALESCE(nombre_cliente, '')) LIKE '%' || v_busqueda || '%'
           OR LOWER(origen) LIKE '%' || v_busqueda || '%'
    )
    SELECT COUNT(*) INTO v_total FROM filtrado;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.dias_vencido DESC, t.numero), '[]'::JSON)
    INTO v_rows
    FROM (
        SELECT *
        FROM filtrado
        ORDER BY dias_vencido DESC, numero
        LIMIT GREATEST(COALESCE(p_limite, 30), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) t;

    RETURN json_build_object('registros', v_rows, 'total', v_total);
END;
$function$;