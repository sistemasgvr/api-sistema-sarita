-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_eliminar_movimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
DROP FUNCTION IF EXISTS inv_eliminar_movimiento(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION inv_eliminar_movimiento(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_mov inv_movimiento%ROWTYPE;
    v_nombre_tipo_mov VARCHAR;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_id_estado_en_almacen INTEGER;
    v_id_almacen_stock INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_mov FROM inv_movimiento WHERE id = p_id AND estado = 1 FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_mov.id_documento_origen IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede anular un movimiento vinculado a un documento; anula el documento origen'
        );
    END IF;

    SELECT nombre INTO v_nombre_tipo_mov FROM gen_lista_opciones WHERE id = v_mov.id_tipo_movimiento;
    v_es_traslado := (v_mov.naturaleza = 'PRODUCTO' AND UPPER(COALESCE(v_nombre_tipo_mov, '')) = 'TRASLADO');
    IF v_es_traslado THEN
        v_es_salida := TRUE;
    ELSIF v_mov.stock_nuevo IS NOT NULL AND v_mov.stock_anterior IS NOT NULL THEN
        v_es_salida := v_mov.stock_nuevo < v_mov.stock_anterior;
    ELSE
        v_es_salida := COALESCE(inv_signo_tipo_movimiento(v_mov.id_tipo_movimiento), 1) < 0;
    END IF;

    IF v_mov.id_producto IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo IS NOT NULL THEN
        -- PRODUCTO siempre mueve el almacén origen. BALON+gas puede haber movido el destino
        -- (p.ej. ENTRADA_LLENADO), según la misma resolución que usó inv_registrar_movimiento.
        IF v_mov.naturaleza = 'PRODUCTO' THEN
            v_id_almacen_stock := v_mov.id_almacen_origen;
        ELSE
            v_id_almacen_stock := COALESCE(
                CASE WHEN v_es_salida THEN v_mov.id_almacen_origen ELSE v_mov.id_almacen_destino END,
                v_mov.id_almacen_origen,
                v_mov.id_almacen_destino
            );
        END IF;

        SELECT id, stock INTO v_id_stock, v_stock_actual
        FROM pro_stock
        WHERE id_almacen = v_id_almacen_stock AND id_producto = v_mov.id_producto AND estado = 1
        FOR UPDATE;

        IF v_id_stock IS NULL THEN
            RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se encontró el registro de stock para revertir el movimiento');
        END IF;

        v_stock_revertido := v_stock_actual + (CASE WHEN v_es_salida THEN v_mov.cantidad ELSE -v_mov.cantidad END);
        IF v_stock_revertido < 0 THEN
            RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se puede anular el movimiento porque revertiría un stock negativo');
        END IF;

        UPDATE pro_stock
        SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
        WHERE id = v_id_stock;

        IF v_es_traslado AND v_mov.id_almacen_destino IS NOT NULL THEN
            SELECT id, stock INTO v_id_stock, v_stock_actual
            FROM pro_stock
            WHERE id_almacen = v_mov.id_almacen_destino AND id_producto = v_mov.id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NULL THEN
                RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se encontró el stock de destino para revertir el traslado');
            END IF;

            v_stock_revertido := v_stock_actual - v_mov.cantidad;
            IF v_stock_revertido < 0 THEN
                RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se puede anular el traslado porque el destino ya no tiene esa cantidad');
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
            WHERE id = v_id_stock;
        END IF;
    END IF;

    IF v_mov.naturaleza = 'BALON' AND v_mov.id_balon IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_balon
        SET
            id_estado_balon = COALESCE(v_mov.id_estado_balon_anterior, v_id_estado_en_almacen, id_estado_balon),
            id_cliente_ubicacion = CASE
                WHEN v_mov.id_estado_balon_anterior IS NOT NULL THEN v_mov.id_cliente_ubicacion_anterior
                ELSE NULL
            END,
            id_almacen = COALESCE(
                v_mov.id_almacen_anterior,
                v_mov.id_almacen_origen,
                v_mov.id_almacen_destino,
                id_almacen
            ),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_mov.id_balon AND estado = 1;
    END IF;

    UPDATE inv_movimiento
    SET estado = 0, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
