CREATE OR REPLACE FUNCTION auth_asignar_usuario_rol(
    p_id_usuario INTEGER,
    p_id_rol INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (
        SELECT 1 FROM auth_usuarios_roles
        WHERE id_usuario = p_id_usuario AND id_rol = p_id_rol AND estado = TRUE
    ) THEN
        RETURN json_build_object('error', 'El usuario ya tiene asignado este rol', 'registro', NULL);
    END IF;

    UPDATE auth_usuarios_roles
    SET estado = TRUE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_usuario = p_id_usuario AND id_rol = p_id_rol
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        INSERT INTO auth_usuarios_roles (id_usuario, id_rol, id_usuario_creacion, id_usuario_modificacion)
        VALUES (p_id_usuario, p_id_rol, p_id_usuario_auditoria, p_id_usuario_auditoria)
        RETURNING id INTO v_id;
    END IF;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT ur.*, u.nombre AS nombre_usuario, r.nombre AS nombre_rol
        FROM auth_usuarios_roles ur
        INNER JOIN auth_usuarios u ON ur.id_usuario = u.id
        INNER JOIN auth_roles r ON ur.id_rol = r.id
        WHERE ur.id = v_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
