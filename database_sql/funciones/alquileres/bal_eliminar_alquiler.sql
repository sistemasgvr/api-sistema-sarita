CREATE OR REPLACE FUNCTION bal_eliminar_alquiler(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_comprobante_venta INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_comprobante_venta
    INTO v_id_comprobante_venta
    FROM bal_alquiler
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_id_comprobante_venta IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el alquiler porque tiene un comprobante vinculado'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_alquiler_detalle WHERE id_alquiler = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el alquiler porque tiene detalles activos'
        );
    END IF;

    UPDATE bal_alquiler
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
