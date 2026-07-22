CREATE OR REPLACE FUNCTION bal_eliminar_movimiento(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_documento_ref INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_documento_ref
    INTO v_id_documento_ref
    FROM bal_movimiento
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_id_documento_ref IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el movimiento porque está vinculado a un documento de origen'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_baja_balon WHERE id_movimiento = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el movimiento porque está vinculado a una baja de cilindro'
        );
    END IF;

    UPDATE bal_movimiento
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
