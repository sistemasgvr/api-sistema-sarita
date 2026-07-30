CREATE OR REPLACE FUNCTION bal_eliminar_mantenimiento(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_comprobante_venta INTEGER;
    v_id_comprobante_compra INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_comprobante_venta, id_comprobante_compra
    INTO v_id_comprobante_venta, v_id_comprobante_compra
    FROM bal_mantenimiento
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_id_comprobante_venta IS NOT NULL OR v_id_comprobante_compra IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el mantenimiento porque tiene un comprobante vinculado'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_balon_ph_historial WHERE id_mantenimiento = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el mantenimiento porque tiene historial de P.H. asociado'
        );
    END IF;

    UPDATE bal_mantenimiento
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
