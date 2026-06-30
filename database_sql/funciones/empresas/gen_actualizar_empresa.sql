CREATE OR REPLACE FUNCTION gen_actualizar_empresa(
    p_id INTEGER,
    p_ruc VARCHAR DEFAULT NULL,
    p_razon_social VARCHAR DEFAULT NULL,
    p_nombre_comercial VARCHAR DEFAULT NULL,
    p_direccion VARCHAR DEFAULT NULL,
    p_telefono VARCHAR DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_empresa
    SET
        ruc = COALESCE(p_ruc, ruc),
        razon_social = COALESCE(p_razon_social, razon_social),
        nombre_comercial = COALESCE(p_nombre_comercial, nombre_comercial),
        direccion = COALESCE(p_direccion, direccion),
        telefono = COALESCE(p_telefono, telefono),
        email = COALESCE(p_email, email),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_empresa(p_id);
END;
$function$;
