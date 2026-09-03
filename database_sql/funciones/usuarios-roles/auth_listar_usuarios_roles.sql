-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_listar_usuarios_roles
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.942Z
DROP FUNCTION IF EXISTS auth_listar_usuarios_roles(p_id_usuario integer, p_id_rol integer, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION auth_listar_usuarios_roles(p_id_usuario integer DEFAULT NULL::integer, p_id_rol integer DEFAULT NULL::integer, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM auth_usuarios_roles ur
    INNER JOIN auth_usuarios u ON ur.id_usuario = u.id
    INNER JOIN auth_roles r ON ur.id_rol = r.id
    WHERE ur.estado = TRUE
      AND (p_id_usuario IS NULL OR ur.id_usuario = p_id_usuario)
      AND (p_id_rol IS NULL OR ur.id_rol = p_id_rol);

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            ur.id,
            ur.id_usuario,
            u.nombre AS nombre_usuario,
            u.correo,
            ur.id_rol,
            r.nombre AS nombre_rol,
            ur.estado,
            ur.fecha_creacion,
            ur.fecha_modificacion
        FROM auth_usuarios_roles ur
        INNER JOIN auth_usuarios u ON ur.id_usuario = u.id
        INNER JOIN auth_roles r ON ur.id_rol = r.id
        WHERE ur.estado = TRUE
          AND (p_id_usuario IS NULL OR ur.id_usuario = p_id_usuario)
          AND (p_id_rol IS NULL OR ur.id_rol = p_id_rol)
        ORDER BY u.nombre, r.nombre
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
