-- precio_unitario en detalles se asume CON IGV incluido (descompone base + impuesto).
CREATE OR REPLACE FUNCTION ven_actualizar_comprobante(
    p_id INTEGER,
    p_fecha DATE DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_detalles JSON DEFAULT NULL,
    p_id_tipo_operacion_sunat INTEGER DEFAULT NULL,
    p_id_comprobante_origen INTEGER DEFAULT NULL,
    p_id_motivo_nota INTEGER DEFAULT NULL,
    p_id_tipo_movimiento INTEGER DEFAULT NULL,
    p_id_tipo_venta INTEGER DEFAULT NULL,
    p_fecha_vencimiento DATE DEFAULT NULL,
    p_tipo_cambio NUMERIC DEFAULT NULL,
    p_id_sucursal INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_condicion_pago INTEGER DEFAULT NULL,
    p_id_moneda INTEGER DEFAULT NULL,
    p_id_medio_pago INTEGER DEFAULT NULL,
    p_glosa VARCHAR DEFAULT NULL,
    p_observaciones VARCHAR DEFAULT NULL,
    p_periodo_contable VARCHAR DEFAULT NULL,
    p_operacion VARCHAR DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_cuotas JSON DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
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
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT es.nombre INTO v_estado_sunat
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
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

    IF p_id_cliente IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

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

    RETURN ven_obtener_comprobante(p_id);
END;
$function$;
