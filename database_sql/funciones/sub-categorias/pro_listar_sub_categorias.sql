CREATE OR REPLACE FUNCTION pro_listar_sub_categorias(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_categoria INTEGER DEFAULT NULL
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
    FROM pro_sub_categoria sc
    INNER JOIN pro_categoria c ON sc.id_categoria = c.id
    WHERE sc.estado = 1
      AND c.estado = 1
      AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
      AND (
          p_busqueda = ''
          OR LOWER(sc.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(sc.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(c.nombre) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            sc.id,
            sc.id_categoria,
            c.nombre AS nombre_categoria,
            sc.nombre,
            sc.descripcion,
            sc.estado,
            sc.fecha_creacion,
            sc.fecha_modificacion,
            sc.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            sc.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM pro_producto p
                WHERE p.id_sub_categoria = sc.id AND p.estado = 1
            ) AS total_productos
        FROM pro_sub_categoria sc
        INNER JOIN pro_categoria c ON sc.id_categoria = c.id
        LEFT JOIN auth_usuarios uc ON sc.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON sc.id_usuario_modificacion = um.id
        WHERE sc.estado = 1
          AND c.estado = 1
          AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
          AND (
              p_busqueda = ''
              OR LOWER(sc.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(sc.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(c.nombre) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY c.nombre ASC, sc.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
