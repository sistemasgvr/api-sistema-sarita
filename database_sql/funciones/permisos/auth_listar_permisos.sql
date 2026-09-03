-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_listar_permisos
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.942Z
DROP FUNCTION IF EXISTS auth_listar_permisos(p_busqueda character varying, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION auth_listar_permisos(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM auth_permisos p
    WHERE p.estado = TRUE
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(p.nombre, p_busqueda)
          OR gen_texto_coincide(COALESCE(p.descripcion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            p.id,
            p.nombre,
            p.descripcion,
            p.estado,
            p.fecha_creacion,
            p.fecha_modificacion,
            p.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            p.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT COUNT(*)::BIGINT
                FROM auth_roles_permisos rp
                WHERE rp.id_permiso = p.id AND rp.estado = TRUE
            ) AS cantidad_roles
        FROM auth_permisos p
        LEFT JOIN auth_usuarios uc ON p.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON p.id_usuario_modificacion = um.id
        WHERE p.estado = TRUE
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(p.nombre, p_busqueda)
              OR gen_texto_coincide(COALESCE(p.descripcion, ''), p_busqueda)
          )
        ORDER BY p.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
