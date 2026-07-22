CREATE OR REPLACE FUNCTION ven_eliminar_comprobante(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT es.nombre INTO v_estado_sunat
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
    WHERE c.id = p_id AND c.estado = 1;

    IF v_estado_sunat IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_estado_sunat = 'ACEPTADO' THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar un comprobante ya aceptado por SUNAT. Use nota de crédito o comunicación de baja.'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_prestamo
        WHERE estado = 1 AND id_comprobante_venta = p_id
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque está vinculado a un préstamo'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_alquiler
        WHERE estado = 1 AND id_comprobante_venta = p_id
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque está vinculado a un alquiler'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_mantenimiento
        WHERE estado = 1 AND id_comprobante_venta = p_id
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque está vinculado a un mantenimiento'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_movimiento_recarga
        WHERE estado = 1 AND id_comprobante = p_id
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque está vinculado a una recarga'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM ven_garantia_movimiento
        WHERE estado = 1 AND id_comprobante = p_id
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque está vinculado a un movimiento de garantía'
        );
    END IF;

    UPDATE ven_comprobante_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_cuotas
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_comprobante
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
