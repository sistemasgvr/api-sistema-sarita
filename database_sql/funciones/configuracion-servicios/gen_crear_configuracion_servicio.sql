CREATE OR REPLACE FUNCTION gen_crear_configuracion_servicio(
    p_codigo VARCHAR,
    p_nombre VARCHAR,
    p_usuario VARCHAR DEFAULT NULL,
    p_contrasena VARCHAR DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL,
    p_url VARCHAR DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_configuracion_servicio (
        codigo,
        nombre,
        usuario,
        contrasena,
        email,
        url,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_codigo,
        p_nombre,
        p_usuario,
        p_contrasena,
        p_email,
        p_url,
        p_observacion,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_configuracion_servicio(v_id);
END;
$function$;
