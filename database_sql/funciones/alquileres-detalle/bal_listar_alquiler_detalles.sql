-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_alquiler_detalles
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.558Z
DROP FUNCTION IF EXISTS bal_listar_alquiler_detalles(p_busqueda character varying, p_limite integer, p_offset integer, p_id_alquiler integer, p_id_balon integer);

CREATE OR REPLACE FUNCTION bal_listar_alquiler_detalles(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_alquiler integer DEFAULT NULL::integer, p_id_balon integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_alquiler_detalle ad
    INNER JOIN bal_alquiler al ON ad.id_alquiler = al.id
    INNER JOIN bal_balon b ON ad.id_balon = b.id
    LEFT JOIN cli_clientes c ON al.id_cliente = c.id
    WHERE ad.estado = 1
      AND (p_id_alquiler IS NULL OR ad.id_alquiler = p_id_alquiler)
      AND (p_id_balon IS NULL OR ad.id_balon = p_id_balon)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(b.codigo_balon, p_busqueda)
          OR gen_texto_coincide(COALESCE(al.numero_alquiler, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            ad.id,
            ad.id_alquiler,
            al.numero_alquiler,
            ad.id_balon,
            b.codigo_balon,
            ad.fecha_devolucion,
            al.id_cliente,
            c.razon_social AS nombre_cliente,
            al.fecha_inicio,
            al.fecha_fin_pactada,
            al.fecha_fin_real,
            al.tarifa_diaria,
            al.id_estado,
            ea.nombre AS nombre_estado,
            CASE
                WHEN ad.fecha_devolucion IS NOT NULL THEN 'DEVUELTO'
                ELSE 'PENDIENTE'
            END AS estado_devolucion,
            ad.estado,
            ad.fecha_creacion
        FROM bal_alquiler_detalle ad
        INNER JOIN bal_alquiler al ON ad.id_alquiler = al.id
        INNER JOIN bal_balon b ON ad.id_balon = b.id
        LEFT JOIN cli_clientes c ON al.id_cliente = c.id
        LEFT JOIN gen_lista_opciones ea ON al.id_estado = ea.id
        WHERE ad.estado = 1
          AND (p_id_alquiler IS NULL OR ad.id_alquiler = p_id_alquiler)
          AND (p_id_balon IS NULL OR ad.id_balon = p_id_balon)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(b.codigo_balon, p_busqueda)
              OR gen_texto_coincide(COALESCE(al.numero_alquiler, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
          )
        ORDER BY al.fecha_inicio DESC NULLS LAST, ad.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
