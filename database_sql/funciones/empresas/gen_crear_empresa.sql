CREATE OR REPLACE FUNCTION gen_crear_empresa(
    p_ruc VARCHAR,
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
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_empresa (
        ruc,
        razon_social,
        nombre_comercial,
        direccion,
        telefono,
        email,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_ruc,
        p_razon_social,
        p_nombre_comercial,
        p_direccion,
        p_telefono,
        p_email,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_empresa(v_id);
END;
$function$;
