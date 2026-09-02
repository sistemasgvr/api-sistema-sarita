-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_listar_roles_permisos
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.499Z
DROP FUNCTION IF EXISTS auth_listar_roles_permisos(p_id_rol integer, p_id_permiso integer, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION auth_listar_roles_permisos(p_id_rol integer DEFAULT NULL::integer, p_id_permiso integer DEFAULT NULL::integer, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM auth_roles_permisos rp
    INNER JOIN auth_roles r ON rp.id_rol = r.id
    INNER JOIN auth_permisos p ON rp.id_permiso = p.id
    WHERE rp.estado = TRUE
      AND (p_id_rol IS NULL OR rp.id_rol = p_id_rol)
      AND (p_id_permiso IS NULL OR rp.id_permiso = p_id_permiso);

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            rp.id,
            rp.id_rol,
            r.nombre AS nombre_rol,
            rp.id_permiso,
            p.nombre AS nombre_permiso,
            rp.estado,
            rp.fecha_creacion,
            rp.fecha_modificacion
        FROM auth_roles_permisos rp
        INNER JOIN auth_roles r ON rp.id_rol = r.id
        INNER JOIN auth_permisos p ON rp.id_permiso = p.id
        WHERE rp.estado = TRUE
          AND (p_id_rol IS NULL OR rp.id_rol = p_id_rol)
          AND (p_id_permiso IS NULL OR rp.id_permiso = p_id_permiso)
        ORDER BY r.nombre, p.nombre
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
