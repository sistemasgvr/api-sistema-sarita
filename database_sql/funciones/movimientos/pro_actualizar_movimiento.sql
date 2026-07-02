CREATE OR REPLACE FUNCTION pro_actualizar_movimiento(
    p_id INTEGER,
    p_fecha DATE DEFAULT NULL,
    p_glosa VARCHAR DEFAULT NULL,
    p_id_documento_ref INTEGER DEFAULT NULL,
    p_id_tipo_documento_ref INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE pro_movimientos
    SET
        fecha = COALESCE(p_fecha, fecha),
        glosa = COALESCE(p_glosa, glosa),
        id_documento_ref = COALESCE(p_id_documento_ref, id_documento_ref),
        id_tipo_documento_ref = COALESCE(p_id_tipo_documento_ref, id_tipo_documento_ref),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN pro_obtener_movimiento(p_id);
END;
$function$;
