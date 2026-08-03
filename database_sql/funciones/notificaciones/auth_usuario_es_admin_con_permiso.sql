-- True si el usuario está activo, tiene rol Administrador y el permiso indicado (o auth.todo).
CREATE OR REPLACE FUNCTION auth_usuario_es_admin_con_permiso(
    p_id_usuario INTEGER,
    p_permiso VARCHAR
)
RETURNS BOOLEAN
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
