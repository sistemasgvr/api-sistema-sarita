-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_listar_sub_categorias
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.787Z
DROP FUNCTION IF EXISTS pro_listar_sub_categorias(p_busqueda character varying, p_limite integer, p_offset integer, p_id_categoria integer, p_solo_activos integer);

CREATE OR REPLACE FUNCTION pro_listar_sub_categorias(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_categoria integer DEFAULT NULL::integer, p_solo_activos integer DEFAULT 1)
 RETURNS json
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
    WHERE (p_solo_activos IS NULL OR sc.estado = p_solo_activos)
      AND (p_solo_activos IS DISTINCT FROM 1 OR c.estado = 1)
      AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(sc.nombre, p_busqueda)
          OR gen_texto_coincide(COALESCE(sc.descripcion, ''), p_busqueda)
          OR gen_texto_coincide(c.nombre, p_busqueda)
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
            ) AS total_productos,
            (
                SELECT COALESCE(json_agg(p.nombre ORDER BY p.nombre ASC), '[]'::JSON)
                FROM pro_producto p
                WHERE p.id_sub_categoria = sc.id AND p.estado = 1
            ) AS nombres_productos
        FROM pro_sub_categoria sc
        INNER JOIN pro_categoria c ON sc.id_categoria = c.id
        LEFT JOIN auth_usuarios uc ON sc.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON sc.id_usuario_modificacion = um.id
        WHERE (p_solo_activos IS NULL OR sc.estado = p_solo_activos)
          AND (p_solo_activos IS DISTINCT FROM 1 OR c.estado = 1)
          AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(sc.nombre, p_busqueda)
              OR gen_texto_coincide(COALESCE(sc.descripcion, ''), p_busqueda)
              OR gen_texto_coincide(c.nombre, p_busqueda)
          )
        ORDER BY c.nombre ASC, sc.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
