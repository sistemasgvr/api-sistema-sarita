-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_actualizar_comprobante
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.799Z
DROP FUNCTION IF EXISTS ven_actualizar_comprobante(p_id integer, p_fecha date, p_id_cliente integer, p_detalles json, p_id_tipo_operacion_sunat integer, p_id_comprobante_origen integer, p_id_motivo_nota integer, p_id_tipo_movimiento integer, p_id_tipo_venta integer, p_fecha_vencimiento date, p_tipo_cambio numeric, p_id_sucursal integer, p_id_almacen integer, p_id_condicion_pago integer, p_id_moneda integer, p_id_medio_pago integer, p_glosa character varying, p_observaciones character varying, p_periodo_contable character varying, p_operacion character varying, p_id_estado integer, p_cuotas json, p_id_usuario_auditoria integer, p_origen_pos character varying);

CREATE OR REPLACE FUNCTION ven_actualizar_comprobante(p_id integer, p_fecha date DEFAULT NULL::date, p_id_cliente integer DEFAULT NULL::integer, p_detalles json DEFAULT NULL::json, p_id_tipo_operacion_sunat integer DEFAULT NULL::integer, p_id_comprobante_origen integer DEFAULT NULL::integer, p_id_motivo_nota integer DEFAULT NULL::integer, p_id_tipo_movimiento integer DEFAULT NULL::integer, p_id_tipo_venta integer DEFAULT NULL::integer, p_fecha_vencimiento date DEFAULT NULL::date, p_tipo_cambio numeric DEFAULT NULL::numeric, p_id_sucursal integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_condicion_pago integer DEFAULT NULL::integer, p_id_moneda integer DEFAULT NULL::integer, p_id_medio_pago integer DEFAULT NULL::integer, p_glosa character varying DEFAULT NULL::character varying, p_observaciones character varying DEFAULT NULL::character varying, p_periodo_contable character varying DEFAULT NULL::character varying, p_operacion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_cuotas json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_origen_pos character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_detalle JSON;
    v_cuota JSON;
    v_item INTEGER;
    v_id_producto INTEGER;
    v_cantidad NUMERIC(12,4);
    v_precio_unitario NUMERIC(12,6);
    v_descuento_linea NUMERIC(12,4);
    v_porcentaje_igv NUMERIC(6,4);
    v_valor_linea NUMERIC(12,4);
    v_impuesto_linea NUMERIC(12,4);
    v_importe_linea NUMERIC(12,4);
    v_codigo_afectacion VARCHAR;
    v_descuento_total NUMERIC(12,4) := 0;
    v_valor_venta_total NUMERIC(12,4) := 0;
    v_igv_total NUMERIC(12,4) := 0;
    v_sub_total NUMERIC(12,4) := 0;
    v_total_importe NUMERIC(12,4) := 0;
    v_exonerado_total NUMERIC(12,4) := 0;
    v_id_estado_cuota INTEGER;
    v_numero_cuota INTEGER;
    v_recalcular BOOLEAN := FALSE;
    v_codigo_tipo VARCHAR;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_fecha DATE;
    v_id_almacen_actual INTEGER;
    v_id_almacen_nuevo INTEGER;
    v_id_tipo_venta INTEGER;
    v_es_nota_credito BOOLEAN := FALSE;
    v_mueve_stock BOOLEAN := FALSE;
    v_afecta_stock BOOLEAN;
    v_id_tipo_mov_salida INTEGER;
    v_id_tipo_mov_ingreso INTEGER;
    v_nombre_tipo_venta VARCHAR;
    v_qty_antigua NUMERIC(12,4);
    v_qty_nueva NUMERIC(12,4);
    v_delta_stock NUMERIC(12,4);
    v_stock_disponible NUMERIC(12,4);
    v_mov_result JSON;
    v_id_tipo_mov_aplicar INTEGER;
    v_cantidad_aplicar NUMERIC(12,4);
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        es.nombre,
        tc.descripcion,
        c.serie,
        c.numero,
        c.fecha,
        c.id_almacen,
        c.id_tipo_venta
    INTO
        v_estado_sunat,
        v_codigo_tipo,
        v_serie,
        v_numero,
        v_fecha,
        v_id_almacen_actual,
        v_id_tipo_venta
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
    LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
    WHERE c.id = p_id AND c.estado = 1;

    IF v_estado_sunat IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_estado_sunat IN ('ACEPTADO', 'BAJA') THEN
        RETURN json_build_object(
            'error', 'No se puede editar un comprobante con estado SUNAT ' || v_estado_sunat,
            'registro', NULL
        );
    END IF;

    -- VSD/NV ya convertida: no permitir editar (stock ya vinculado al CPE destino)
    IF v_codigo_tipo IN ('NV', 'VSD') AND EXISTS (
        SELECT 1
        FROM ven_comprobante
        WHERE id_comprobante_origen = p_id
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'No se puede editar una venta sin documento que ya fue convertida a boleta/factura',
            'registro',
            NULL
        );
    END IF;

    IF p_id_cliente IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_es_nota_credito := (v_codigo_tipo = '07');
    v_mueve_stock := (v_codigo_tipo IN ('01', '03', '07', 'NV', 'VSD'));
    v_id_almacen_nuevo := COALESCE(p_id_almacen, v_id_almacen_actual);
    v_fecha := COALESCE(p_fecha, v_fecha);
    v_id_tipo_venta := COALESCE(p_id_tipo_venta, v_id_tipo_venta);

    IF p_detalles IS NOT NULL THEN
        IF json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
            RETURN json_build_object('error', 'Debe registrar al menos un detalle', 'registro', NULL);
        END IF;

        v_recalcular := TRUE;

        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_id_producto := NULLIF((v_detalle->>'id_producto')::INTEGER, 0);
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
            v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
            v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
            v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);

            IF v_id_producto IS NULL OR v_cantidad <= 0 THEN
                RETURN json_build_object('error', 'Detalle inválido: producto y cantidad son obligatorios', 'registro', NULL);
            END IF;

            SELECT
                REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
                COALESCE(p.es_gas, FALSE)
            INTO v_nombre_unidad, v_es_gas
            FROM pro_producto p
            LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
            WHERE p.id = v_id_producto;

            IF NOT COALESCE(v_es_gas, FALSE)
               AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
               AND v_cantidad <> TRUNC(v_cantidad)
            THEN
                RETURN json_build_object(
                    'error',
                    'La cantidad de ' || COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto)
                        || ' debe ser entera (unidad de medida UNID)',
                    'registro',
                    NULL
                );
            END IF;

            -- precio_unitario del catálogo ya incluye IGV
            v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);

            IF v_codigo_afectacion = '10' THEN
                v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
                v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
            ELSE
                v_valor_linea := v_importe_linea;
                v_impuesto_linea := 0;
                IF v_codigo_afectacion = '20' THEN
                    v_exonerado_total := v_exonerado_total + v_valor_linea;
                END IF;
            END IF;

            v_descuento_total := v_descuento_total + v_descuento_linea;
            v_valor_venta_total := v_valor_venta_total + v_valor_linea;
            v_igv_total := v_igv_total + v_impuesto_linea;
            v_sub_total := v_sub_total + v_importe_linea;
            v_total_importe := v_total_importe + v_importe_linea;
        END LOOP;
    END IF;

    -- Ajuste de stock por diferencias de detalle / cambio de almacén
    IF v_mueve_stock AND (p_detalles IS NOT NULL OR p_id_almacen IS NOT NULL) THEN
        IF EXISTS (
            SELECT 1
            FROM ven_comprobante_detalle d
            INNER JOIN pro_producto p ON p.id = d.id_producto
            WHERE d.id_comprobante = p_id
              AND d.estado = 1
              AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
        ) OR (
            p_detalles IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM json_array_elements(p_detalles) j
                INNER JOIN pro_producto p ON p.id = (j.value->>'id_producto')::INTEGER
                WHERE ven_producto_mueve_kardex_venta(p.id, j.value->>'descripcion')
            )
        ) THEN
            IF v_id_almacen_nuevo IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'Debe indicar el almacén para ajustar stock de los productos',
                    'registro',
                    NULL
                );
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_nuevo AND estado = 1
            ) THEN
                RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
            END IF;

            SELECT lo.id INTO v_id_tipo_mov_salida
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'SALIDA' AND lo.estado = 1
            LIMIT 1;

            SELECT lo.id INTO v_id_tipo_mov_ingreso
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'INGRESO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_mov_salida IS NULL OR v_id_tipo_mov_ingreso IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontraron tipos de movimiento SALIDA/INGRESO',
                    'registro',
                    NULL
                );
            END IF;

            SELECT lo.nombre INTO v_nombre_tipo_venta
            FROM gen_lista_opciones lo
            WHERE lo.id = v_id_tipo_venta;

            IF p_detalles IS NULL THEN
                -- Solo cambia almacén: revertir en el anterior y aplicar en el nuevo
                IF v_id_almacen_actual IS DISTINCT FROM v_id_almacen_nuevo THEN
                    FOR v_id_producto, v_qty_antigua IN
                        SELECT d.id_producto, SUM(d.cantidad)
                        FROM ven_comprobante_detalle d
                        INNER JOIN pro_producto p ON p.id = d.id_producto
                        WHERE d.id_comprobante = p_id
                          AND d.estado = 1
                          AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                        GROUP BY d.id_producto
                    LOOP
                        IF v_es_nota_credito THEN
                            -- NC había ingresado: al salir del almacén viejo se revierte con SALIDA
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                        END IF;

                        v_mov_result := inv_registrar_movimiento(
                            'PRODUCTO',
                            CASE WHEN v_es_nota_credito THEN 'SALIDA' ELSE 'INGRESO' END,
                            v_fecha,
                            v_id_producto,
                            NULL,
                            v_qty_antigua,
                            v_id_almacen_actual,
                            NULL,
                            NULL,
                            ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                            p_id,
                            format('Cambio almacén %s-%s (revertir)', v_serie, v_numero),
                            p_id_usuario_auditoria,
                            NULL,
                            NULL,
                            TRUE
                        );
                        IF v_mov_result->>'error' IS NOT NULL THEN
                            RETURN json_build_object('error', v_mov_result->>'error', 'registro', NULL);
                        END IF;

                        IF v_es_nota_credito THEN
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                        ELSE
                            SELECT COALESCE(s.stock, 0)
                            INTO v_stock_disponible
                            FROM pro_stock s
                            WHERE s.id_almacen = v_id_almacen_nuevo
                              AND s.id_producto = v_id_producto
                              AND s.estado = 1;

                            IF COALESCE(v_stock_disponible, 0) < v_qty_antigua THEN
                                RETURN json_build_object(
                                    'error',
                                    format(
                                        'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                        COALESCE(v_stock_disponible, 0),
                                        v_qty_antigua
                                    ),
                                    'registro',
                                    NULL
                                );
                            END IF;
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                        END IF;

                        v_mov_result := inv_registrar_movimiento(
                            'PRODUCTO',
                            CASE WHEN v_es_nota_credito THEN 'INGRESO' ELSE 'SALIDA' END,
                            v_fecha,
                            v_id_producto,
                            NULL,
                            v_qty_antigua,
                            v_id_almacen_nuevo,
                            NULL,
                            NULL,
                            ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                            p_id,
                            format('Cambio almacén %s-%s (aplicar)', v_serie, v_numero),
                            p_id_usuario_auditoria,
                            NULL,
                            NULL,
                            TRUE
                        );
                        IF v_mov_result->>'error' IS NOT NULL THEN
                            RETURN json_build_object('error', v_mov_result->>'error', 'registro', NULL);
                        END IF;
                    END LOOP;
                END IF;
            ELSIF v_id_almacen_actual IS DISTINCT FROM v_id_almacen_nuevo THEN
                -- Cambia almacén y detalle: revertir todo lo antiguo y aplicar lo nuevo
                FOR v_id_producto, v_qty_antigua IN
                    SELECT d.id_producto, SUM(d.cantidad)
                    FROM ven_comprobante_detalle d
                    INNER JOIN pro_producto p ON p.id = d.id_producto
                    WHERE d.id_comprobante = p_id
                      AND d.estado = 1
                      AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                    GROUP BY d.id_producto
                LOOP
                    IF v_es_nota_credito THEN
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                    ELSE
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_es_nota_credito THEN 'SALIDA' ELSE 'INGRESO' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_qty_antigua,
                        v_id_almacen_actual,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Cambio almacén %s-%s (revertir)', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RETURN json_build_object('error', v_mov_result->>'error', 'registro', NULL);
                    END IF;
                END LOOP;

                FOR v_id_producto, v_qty_nueva IN
                    SELECT
                        (value->>'id_producto')::INTEGER,
                        SUM(COALESCE((value->>'cantidad')::NUMERIC, 0))
                    FROM json_array_elements(p_detalles)
                    GROUP BY (value->>'id_producto')::INTEGER
                LOOP
                    IF NOT ven_producto_mueve_kardex_venta(v_id_producto, NULL) THEN
                        CONTINUE;
                    END IF;

                    IF v_es_nota_credito THEN
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                    ELSE
                        SELECT COALESCE(s.stock, 0)
                        INTO v_stock_disponible
                        FROM pro_stock s
                        WHERE s.id_almacen = v_id_almacen_nuevo
                          AND s.id_producto = v_id_producto
                          AND s.estado = 1;

                        IF COALESCE(v_stock_disponible, 0) < v_qty_nueva THEN
                            RETURN json_build_object(
                                'error',
                                format(
                                    'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                    COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                    COALESCE(v_stock_disponible, 0),
                                    v_qty_nueva
                                ),
                                'registro',
                                NULL
                            );
                        END IF;
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_es_nota_credito THEN 'INGRESO' ELSE 'SALIDA' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_qty_nueva,
                        v_id_almacen_nuevo,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Ajuste edición %s-%s', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RETURN json_build_object('error', v_mov_result->>'error', 'registro', NULL);
                    END IF;
                END LOOP;
            ELSE
                -- Mismo almacén: solo deltas por producto
                FOR v_id_producto, v_qty_antigua, v_qty_nueva IN
                    SELECT
                        COALESCE(o.id_producto, n.id_producto),
                        COALESCE(o.cantidad, 0),
                        COALESCE(n.cantidad, 0)
                    FROM (
                        SELECT d.id_producto, SUM(d.cantidad) AS cantidad
                        FROM ven_comprobante_detalle d
                        INNER JOIN pro_producto p ON p.id = d.id_producto
                        WHERE d.id_comprobante = p_id
                          AND d.estado = 1
                          AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                        GROUP BY d.id_producto
                    ) o
                    FULL OUTER JOIN (
                        SELECT
                            (value->>'id_producto')::INTEGER AS id_producto,
                            SUM(COALESCE((value->>'cantidad')::NUMERIC, 0)) AS cantidad
                        FROM json_array_elements(p_detalles)
                        GROUP BY (value->>'id_producto')::INTEGER
                    ) n ON n.id_producto = o.id_producto
                    INNER JOIN pro_producto p ON p.id = COALESCE(o.id_producto, n.id_producto)
                    WHERE ven_producto_mueve_kardex_venta(p.id, NULL)
                LOOP
                    v_delta_stock := v_qty_nueva - v_qty_antigua;
                    IF v_delta_stock = 0 THEN
                        CONTINUE;
                    END IF;

                    -- Venta: +qty → SALIDA; -qty → INGRESO. NC: sentido inverso.
                    IF v_es_nota_credito THEN
                        IF v_delta_stock > 0 THEN
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                            v_cantidad_aplicar := v_delta_stock;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                            v_cantidad_aplicar := ABS(v_delta_stock);
                        END IF;
                    ELSE
                        IF v_delta_stock > 0 THEN
                            SELECT COALESCE(s.stock, 0)
                            INTO v_stock_disponible
                            FROM pro_stock s
                            WHERE s.id_almacen = v_id_almacen_nuevo
                              AND s.id_producto = v_id_producto
                              AND s.estado = 1;

                            IF COALESCE(v_stock_disponible, 0) < v_delta_stock THEN
                                RETURN json_build_object(
                                    'error',
                                    format(
                                        'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                        COALESCE(v_stock_disponible, 0),
                                        v_delta_stock
                                    ),
                                    'registro',
                                    NULL
                                );
                            END IF;
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                            v_cantidad_aplicar := v_delta_stock;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                            v_cantidad_aplicar := ABS(v_delta_stock);
                        END IF;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_id_tipo_mov_aplicar = v_id_tipo_mov_salida THEN 'SALIDA' ELSE 'INGRESO' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_cantidad_aplicar,
                        v_id_almacen_nuevo,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Ajuste edición %s-%s', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RETURN json_build_object('error', v_mov_result->>'error', 'registro', NULL);
                    END IF;
                END LOOP;
            END IF;
        END IF;
    END IF;

    UPDATE ven_comprobante
    SET
        fecha = COALESCE(p_fecha, fecha),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_tipo_operacion_sunat = COALESCE(p_id_tipo_operacion_sunat, id_tipo_operacion_sunat),
        id_comprobante_origen = COALESCE(p_id_comprobante_origen, id_comprobante_origen),
        id_motivo_nota = COALESCE(p_id_motivo_nota, id_motivo_nota),
        id_tipo_movimiento = COALESCE(p_id_tipo_movimiento, id_tipo_movimiento),
        id_tipo_venta = COALESCE(p_id_tipo_venta, id_tipo_venta),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        tipo_cambio = COALESCE(p_tipo_cambio, tipo_cambio),
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_condicion_pago = COALESCE(p_id_condicion_pago, id_condicion_pago),
        id_moneda = COALESCE(p_id_moneda, id_moneda),
        id_medio_pago = COALESCE(p_id_medio_pago, id_medio_pago),
        sub_total = CASE WHEN v_recalcular THEN v_sub_total ELSE sub_total END,
        descuento = CASE WHEN v_recalcular THEN v_descuento_total ELSE descuento END,
        valor_venta = CASE WHEN v_recalcular THEN v_valor_venta_total ELSE valor_venta END,
        igv = CASE WHEN v_recalcular THEN v_igv_total ELSE igv END,
        total_importe = CASE WHEN v_recalcular THEN v_total_importe ELSE total_importe END,
        exonerado = CASE WHEN v_recalcular THEN v_exonerado_total ELSE exonerado END,
        glosa = COALESCE(p_glosa, glosa),
        observaciones = COALESCE(p_observaciones, observaciones),
        periodo_contable = COALESCE(p_periodo_contable, periodo_contable),
        operacion = COALESCE(p_operacion, operacion),
        origen_pos = COALESCE(NULLIF(TRIM(p_origen_pos), ''), origen_pos),
        id_estado = COALESCE(p_id_estado, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF p_detalles IS NOT NULL THEN
        UPDATE ven_comprobante_detalle
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_comprobante = p_id AND estado = 1;

        v_item := 0;
        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_item := v_item + 1;
            v_id_producto := (v_detalle->>'id_producto')::INTEGER;
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
            v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
            v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
            v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);
            -- precio_unitario del catálogo ya incluye IGV
            v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);

            IF v_codigo_afectacion = '10' THEN
                v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
                v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
            ELSE
                v_valor_linea := v_importe_linea;
                v_impuesto_linea := 0;
            END IF;

            INSERT INTO ven_comprobante_detalle (
                id_comprobante, item, id_producto, descripcion, id_unidad_medida,
                cantidad, precio_unitario, descuento, valor_venta, porcentaje_igv,
                id_afectacion_igv, impuesto, importe,
                id_balon, capacidad_cilindro, id_estado_cilindro,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                p_id,
                COALESCE(NULLIF((v_detalle->>'item')::INTEGER, 0), v_item),
                v_id_producto,
                NULLIF(v_detalle->>'descripcion', ''),
                NULLIF((v_detalle->>'id_unidad_medida')::INTEGER, 0),
                v_cantidad,
                v_precio_unitario,
                v_descuento_linea,
                v_valor_linea,
                v_porcentaje_igv,
                NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0),
                v_impuesto_linea,
                v_importe_linea,
                NULLIF((v_detalle->>'id_balon')::INTEGER, 0),
                NULLIF((v_detalle->>'capacidad_cilindro')::NUMERIC, 0),
                NULLIF((v_detalle->>'id_estado_cilindro')::INTEGER, 0),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    IF p_cuotas IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_cuota
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoCuota' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
        LIMIT 1;

        UPDATE ven_cuotas
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_comprobante = p_id AND estado = 1;

        IF json_typeof(p_cuotas) = 'array' THEN
            FOR v_cuota IN SELECT value FROM json_array_elements(p_cuotas)
            LOOP
                v_numero_cuota := COALESCE((v_cuota->>'numero_cuota')::INTEGER, 0);
                IF v_numero_cuota <= 0 THEN
                    CONTINUE;
                END IF;

                INSERT INTO ven_cuotas (
                    id_comprobante, numero_cuota, fecha_vencimiento, monto,
                    monto_pagado, id_estado,
                    id_usuario_creacion, id_usuario_modificacion
                )
                VALUES (
                    p_id,
                    v_numero_cuota,
                    (v_cuota->>'fecha_vencimiento')::DATE,
                    COALESCE((v_cuota->>'monto')::NUMERIC, 0),
                    COALESCE((v_cuota->>'monto_pagado')::NUMERIC, 0),
                    COALESCE(NULLIF((v_cuota->>'id_estado')::INTEGER, 0), v_id_estado_cuota),
                    p_id_usuario_auditoria,
                    p_id_usuario_auditoria
                );
            END LOOP;
        END IF;
    END IF;

    IF NOT v_es_nota_credito THEN
        PERFORM ven_sincronizar_cxc_venta(p_id, p_id_usuario_auditoria);
    END IF;

    RETURN ven_obtener_comprobante(p_id);
END;
$function$
