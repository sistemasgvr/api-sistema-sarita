-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_tipos_balon
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.579Z
DROP FUNCTION IF EXISTS bal_listar_tipos_balon(p_busqueda character varying, p_limite integer, p_offset integer, p_id_gas integer);

CREATE OR REPLACE FUNCTION bal_listar_tipos_balon(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_gas integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_tipo_balon tb
    LEFT JOIN pro_producto g ON tb.id_gas = g.id
    WHERE tb.estado = 1
      AND (p_id_gas IS NULL OR tb.id_gas = p_id_gas)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(tb.nombre, p_busqueda)
          OR gen_texto_coincide(COALESCE(g.nombre, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            tb.id,
            tb.nombre,
            tb.id_gas,
            g.nombre AS nombre_gas,
            tb.capacidad,
            tb.capacidad_lb,
            tb.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            tb.peso,
            tb.peso_tara_lb,
            tb.presion_llenado_psi,
            tb.vigencia_ph_anios,
            tb.estado,
            tb.fecha_creacion,
            tb.fecha_modificacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_balon b
                WHERE b.id_tipo_balon = tb.id AND b.estado = 1
            ) AS total_balones
        FROM bal_tipo_balon tb
        LEFT JOIN pro_producto g ON tb.id_gas = g.id
        LEFT JOIN gen_lista_opciones um ON tb.id_unidad_medida = um.id
        WHERE tb.estado = 1
          AND (p_id_gas IS NULL OR tb.id_gas = p_id_gas)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(tb.nombre, p_busqueda)
              OR gen_texto_coincide(COALESCE(g.nombre, ''), p_busqueda)
          )
        ORDER BY tb.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
