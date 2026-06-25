CREATE OR REPLACE FUNCTION auth_actualizar_usuario(
    p_id INTEGER,
    p_nombre VARCHAR DEFAULT NULL,
    p_correo VARCHAR DEFAULT NULL,
    p_contrasena VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_correo IS NOT NULL AND EXISTS (
        SELECT 1 FROM auth_usuarios
        WHERE LOWER(correo) = LOWER(p_correo) AND id <> p_id AND estado = TRUE
    ) THEN
        RETURN json_build_object('error', 'El correo ya está registrado', 'registro', NULL);
    END IF;

    UPDATE auth_usuarios
    SET
        nombre = COALESCE(p_nombre, nombre),
        correo = COALESCE(LOWER(p_correo), correo),
        contrasena = COALESCE(p_contrasena, contrasena),
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = TRUE;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN auth_obtener_usuario(p_id);
END;
$function$;
