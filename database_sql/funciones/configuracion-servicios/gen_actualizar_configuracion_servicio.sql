CREATE OR REPLACE FUNCTION gen_actualizar_configuracion_servicio(
    p_id INTEGER,
    p_codigo VARCHAR DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
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
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_configuracion_servicio
    SET
        codigo = COALESCE(p_codigo, codigo),
        nombre = COALESCE(p_nombre, nombre),
        usuario = COALESCE(p_usuario, usuario),
        contrasena = COALESCE(p_contrasena, contrasena),
        email = COALESCE(p_email, email),
        url = COALESCE(p_url, url),
        observacion = COALESCE(p_observacion, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_configuracion_servicio(p_id);
END;
$function$;
