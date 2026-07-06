CREATE OR REPLACE FUNCTION gen_crear_chofer(
    p_nombres               VARCHAR,
    p_id_cliente            INTEGER DEFAULT NULL,
    p_apellido_paterno      VARCHAR DEFAULT NULL,
    p_apellido_materno      VARCHAR DEFAULT NULL,
    p_id_tipo_documento     INTEGER DEFAULT NULL,
    p_numero_documento      VARCHAR DEFAULT NULL,
    p_brevete               VARCHAR DEFAULT NULL,
    p_telefono              VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria  INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_chofer (
        id_cliente, apellido_paterno, apellido_materno, nombres,
        id_tipo_documento, numero_documento, brevete, telefono,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_cliente, p_apellido_paterno, p_apellido_materno, p_nombres,
        p_id_tipo_documento, p_numero_documento, p_brevete, p_telefono,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_chofer(v_id);
END;
$function$;
