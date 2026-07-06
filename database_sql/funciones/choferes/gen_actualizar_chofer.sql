CREATE OR REPLACE FUNCTION gen_actualizar_chofer(
    p_id                    INTEGER,
    p_id_cliente            INTEGER DEFAULT NULL,
    p_apellido_paterno      VARCHAR DEFAULT NULL,
    p_apellido_materno      VARCHAR DEFAULT NULL,
    p_nombres               VARCHAR DEFAULT NULL,
    p_id_tipo_documento     INTEGER DEFAULT NULL,
    p_numero_documento      VARCHAR DEFAULT NULL,
    p_brevete               VARCHAR DEFAULT NULL,
    p_telefono              VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria  INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_chofer
    SET
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        apellido_paterno = COALESCE(p_apellido_paterno, apellido_paterno),
        apellido_materno = COALESCE(p_apellido_materno, apellido_materno),
        nombres = COALESCE(p_nombres, nombres),
        id_tipo_documento = COALESCE(p_id_tipo_documento, id_tipo_documento),
        numero_documento = COALESCE(p_numero_documento, numero_documento),
        brevete = COALESCE(p_brevete, brevete),
        telefono = COALESCE(p_telefono, telefono),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_chofer(p_id);
END;
$function$;
