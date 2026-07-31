DROP FUNCTION IF EXISTS pro_listar_categorias(VARCHAR, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION pro_listar_categorias(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_solo_activos INTEGER DEFAULT 1
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
    FROM pro_categoria c
    WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(c.nombre, p_busqueda)
          OR gen_texto_coincide(COALESCE(c.descripcion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            c.id,
            c.nombre,
            c.descripcion,
            c.estado,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM pro_sub_categoria sc
                WHERE sc.id_categoria = c.id AND sc.estado = 1
            ) AS total_sub_categorias
        FROM pro_categoria c
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON c.id_usuario_modificacion = um.id
        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(c.nombre, p_busqueda)
              OR gen_texto_coincide(COALESCE(c.descripcion, ''), p_busqueda)
          )
        ORDER BY c.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
