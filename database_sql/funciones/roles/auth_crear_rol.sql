CREATE OR REPLACE FUNCTION auth_crear_rol(
    p_nombre VARCHAR,
    p_descripcion VARCHAR DEFAULT NULL,
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

    INSERT INTO auth_roles (nombre, descripcion, id_usuario_creacion, id_usuario_modificacion)
    VALUES (p_nombre, p_descripcion, p_id_usuario_auditoria, p_id_usuario_auditoria)
    RETURNING id INTO v_id;

    RETURN auth_obtener_rol(v_id);
END;
$function$;
