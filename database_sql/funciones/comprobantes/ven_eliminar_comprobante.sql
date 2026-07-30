CREATE OR REPLACE FUNCTION ven_eliminar_comprobante(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_movimiento RECORD;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_afecta_stock BOOLEAN;
    v_es_salida BOOLEAN;
    v_nombre_tipo_movimiento VARCHAR;
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
        SELECT 1
        FROM ven_comprobante
        WHERE id_comprobante_origen = p_id
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque tiene documentos derivados (boleta/factura/nota)'
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

    -- Revertir stock de movimientos vinculados al comprobante
    FOR v_movimiento IN
        SELECT *
        FROM pro_movimientos
        WHERE id_documento_ref = p_id
          AND estado = 1
        ORDER BY id
        FOR UPDATE
    LOOP
        SELECT COALESCE(afecta_stock, FALSE)
        INTO v_afecta_stock
        FROM pro_producto
        WHERE id = v_movimiento.id_producto;

        IF v_afecta_stock
           AND v_movimiento.stock_anterior IS NOT NULL
           AND v_movimiento.stock_nuevo IS NOT NULL THEN
            SELECT nombre INTO v_nombre_tipo_movimiento
            FROM gen_lista_opciones
            WHERE id = v_movimiento.id_tipo_movimiento;

            v_es_salida := v_nombre_tipo_movimiento ILIKE '%SALIDA%';

            SELECT id, stock INTO v_id_stock, v_stock_actual
            FROM pro_stock
            WHERE id_almacen = v_movimiento.id_almacen
              AND id_producto = v_movimiento.id_producto
              AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NULL THEN
                RETURN json_build_object(
                    'eliminado', FALSE,
                    'id', p_id,
                    'error', 'No se encontró el registro de stock para revertir el movimiento del comprobante'
                );
            END IF;

            IF v_es_salida THEN
                v_stock_revertido := v_stock_actual + v_movimiento.cantidad;
            ELSE
                v_stock_revertido := v_stock_actual - v_movimiento.cantidad;
            END IF;

            IF v_stock_revertido < 0 THEN
                RETURN json_build_object(
                    'eliminado', FALSE,
                    'id', p_id,
                    'error', 'No se puede eliminar el comprobante porque revertiría un stock negativo'
                );
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_revertido,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_stock;
        END IF;

        UPDATE pro_movimientos
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_movimiento.id AND estado = 1;
    END LOOP;

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
