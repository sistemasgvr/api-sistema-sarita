CREATE OR REPLACE FUNCTION bal_listar_tipos_balon(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_gas INTEGER DEFAULT NULL
)
RETURNS JSON
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
          OR LOWER(tb.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(g.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            tb.id,
            tb.nombre,
            tb.id_gas,
            g.nombre AS nombre_gas,
            tb.capacidad,
            tb.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            tb.peso,
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
              OR LOWER(tb.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(g.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY tb.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
