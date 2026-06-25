CREATE OR REPLACE FUNCTION auth_obtener_permisos_usuario(p_id_usuario INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_permisos JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(DISTINCT p.nombre ORDER BY p.nombre), '[]'::JSON)
    INTO v_permisos
    FROM auth_usuarios_roles ur
    INNER JOIN auth_roles r ON ur.id_rol = r.id
    INNER JOIN auth_roles_permisos rp ON rp.id_rol = r.id
    INNER JOIN auth_permisos p ON rp.id_permiso = p.id
    WHERE ur.id_usuario = p_id_usuario
      AND ur.estado = TRUE
      AND r.estado = TRUE
      AND rp.estado = TRUE
      AND p.estado = TRUE;

    RETURN json_build_object('permisos', v_permisos);
END;
$function$;
