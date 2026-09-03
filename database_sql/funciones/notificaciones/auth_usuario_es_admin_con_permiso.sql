-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_usuario_es_admin_con_permiso
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.943Z
DROP FUNCTION IF EXISTS auth_usuario_es_admin_con_permiso(p_id_usuario integer, p_permiso character varying);

CREATE OR REPLACE FUNCTION auth_usuario_es_admin_con_permiso(p_id_usuario integer, p_permiso character varying)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_ok BOOLEAN := FALSE;
BEGIN
    IF p_id_usuario IS NULL OR NULLIF(TRIM(p_permiso), '') IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM auth_usuarios u
        INNER JOIN auth_usuarios_roles ur ON ur.id_usuario = u.id AND ur.estado = TRUE
        INNER JOIN auth_roles r ON r.id = ur.id_rol AND r.estado = TRUE AND r.nombre = 'Administrador'
        INNER JOIN auth_roles_permisos rp ON rp.id_rol = r.id AND rp.estado = TRUE
        INNER JOIN auth_permisos p ON p.id = rp.id_permiso AND p.estado = TRUE
        WHERE u.id = p_id_usuario
          AND u.estado = TRUE
          AND (
              p.nombre = TRIM(p_permiso)
              OR p.nombre = 'auth.todo'
          )
    )
    INTO v_ok;

    RETURN COALESCE(v_ok, FALSE);
END;
$function$;
