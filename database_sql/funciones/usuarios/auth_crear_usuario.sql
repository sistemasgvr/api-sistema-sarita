CREATE OR REPLACE FUNCTION auth_crear_usuario(
    p_nombre VARCHAR,
    p_correo VARCHAR,
    p_contrasena VARCHAR,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (SELECT 1 FROM auth_usuarios WHERE LOWER(correo) = LOWER(p_correo) AND estado = TRUE) THEN
        RETURN json_build_object('error', 'El correo ya está registrado', 'registro', NULL);
    END IF;

    INSERT INTO auth_usuarios (nombre, correo, contrasena)
    VALUES (p_nombre, LOWER(p_correo), p_contrasena)
    RETURNING id INTO v_id;

    RETURN auth_obtener_usuario(v_id);
END;
$function$;
