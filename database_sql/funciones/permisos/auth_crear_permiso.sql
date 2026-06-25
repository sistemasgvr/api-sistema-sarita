CREATE OR REPLACE FUNCTION auth_crear_permiso(
    p_nombre VARCHAR,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO auth_permisos (nombre, descripcion, id_usuario_creacion, id_usuario_modificacion)
    VALUES (p_nombre, p_descripcion, p_id_usuario_auditoria, p_id_usuario_auditoria)
    RETURNING id INTO v_id;

    RETURN auth_obtener_permiso(v_id);
END;
$function$;
