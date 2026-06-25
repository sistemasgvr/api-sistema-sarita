CREATE OR REPLACE FUNCTION auth_listar_usuarios_roles(
    p_id_usuario INTEGER DEFAULT NULL,
    p_id_rol INTEGER DEFAULT NULL,
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0
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
