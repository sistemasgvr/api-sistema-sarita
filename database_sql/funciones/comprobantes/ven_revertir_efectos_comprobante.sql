-- Revierte kardex de producto y CxC impaga. No da de baja el CPE (eso lo hace eliminar/baja).
CREATE OR REPLACE FUNCTION ven_revertir_efectos_comprobante(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_exigir_sin_pagos BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_hay_pagos BOOLEAN;
    v_codigo_tipo VARCHAR;
    v_nombre_tipo_venta VARCHAR;
    v_codigo_tipo_documento VARCHAR;
    v_inv_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_hay_pagos := fin_cuenta_documento_tiene_pagos(p_id, NULL);

    IF p_exigir_sin_pagos AND v_hay_pagos THEN
        RETURN json_build_object(
            'ok', FALSE,
            'error', 'No se puede eliminar: la cuenta por cobrar tiene pagos. Anule primero los pagos en Finanzas.'
        );
    END IF;

    -- Resolver el código del tipo de documento para inv_revertir_por_documento
    SELECT
        tc.descripcion,
        COALESCE(tv.nombre, 'VENTA')
    INTO v_codigo_tipo, v_nombre_tipo_venta
    FROM ven_comprobante c
    INNER JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
    LEFT JOIN gen_lista_opciones tv ON c.id_tipo_venta = tv.id
    WHERE c.id = p_id AND c.estado = 1;

    v_codigo_tipo_documento := ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta);

    -- Revertir kardex de producto via inv_revertir_por_documento
    v_inv_result := inv_revertir_por_documento(
        v_codigo_tipo_documento,
        p_id,
        p_id_usuario_auditoria
    );

    -- Si no había movimientos en inv_movimiento, intentar con pro_movimientos (fallback legado)
    -- TODO: eliminar este fallback una vez que todo el tráfico pase por inv_movimiento
    IF (v_inv_result->>'revertidos')::INTEGER = 0 THEN
        DECLARE
            v_movimiento RECORD;
            v_id_stock INTEGER;
            v_stock_actual NUMERIC(12,4);
            v_stock_revertido NUMERIC(12,4);
            v_afecta_stock BOOLEAN;
            v_es_salida BOOLEAN;
            v_nombre_tipo_movimiento VARCHAR;
        BEGIN
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
                            'ok', FALSE,
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
                            'ok', FALSE,
                            'error', 'No se puede revertir el comprobante porque dejaría stock negativo'
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
        END;
    END IF;

    IF NOT v_hay_pagos THEN
        PERFORM fin_bajar_cuentas_documento(p_id_usuario_auditoria, p_id, NULL);
    END IF;

    BEGIN
        PERFORM ven_cerrar_custodia_comprobante(p_id, p_id_usuario_auditoria);
    EXCEPTION WHEN OTHERS THEN
        RETURN json_build_object('ok', FALSE, 'error', SQLERRM);
    END;

    RETURN json_build_object('ok', TRUE, 'error', NULL);
END;
$function$;
