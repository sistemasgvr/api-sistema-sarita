CREATE OR REPLACE FUNCTION pro_eliminar_movimiento(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_movimiento pro_movimientos%ROWTYPE;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_afecta_stock BOOLEAN;
    v_es_salida BOOLEAN;
    v_nombre_tipo_movimiento VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_movimiento
    FROM pro_movimientos
    WHERE id = p_id AND estado = 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_movimiento.id_documento_ref IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede anular un movimiento vinculado a una venta/comprobante'
        );
    END IF;

    SELECT afecta_stock INTO v_afecta_stock
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
                'error', 'No se encontró el registro de stock para revertir el movimiento'
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
                'error', 'No se puede anular el movimiento porque revertiría un stock negativo'
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
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
