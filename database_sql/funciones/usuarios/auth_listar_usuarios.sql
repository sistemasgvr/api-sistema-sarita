-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_listar_usuarios
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.942Z
DROP FUNCTION IF EXISTS auth_listar_usuarios(p_busqueda character varying, p_limite integer, p_offset integer, p_estado boolean);

CREATE OR REPLACE FUNCTION auth_listar_usuarios(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_estado boolean DEFAULT NULL::boolean)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM auth_usuarios u
    WHERE (p_estado IS NULL OR u.estado = p_estado)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(u.nombre, p_busqueda)
          OR gen_texto_coincide(u.correo, p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            u.id,
            u.nombre,
            u.correo,
            u.estado,
            u.fecha_creacion,
            u.fecha_modificacion,
            (
                SELECT COALESCE(json_agg(json_build_object(
                    'id', r.id,
                    'nombre', r.nombre
                )), '[]'::JSON)
                FROM auth_usuarios_roles ur
                INNER JOIN auth_roles r ON ur.id_rol = r.id
                WHERE ur.id_usuario = u.id AND ur.estado = TRUE AND r.estado = TRUE
            ) AS roles
        FROM auth_usuarios u
        WHERE (p_estado IS NULL OR u.estado = p_estado)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(u.nombre, p_busqueda)
              OR gen_texto_coincide(u.correo, p_busqueda)
          )
        ORDER BY u.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
