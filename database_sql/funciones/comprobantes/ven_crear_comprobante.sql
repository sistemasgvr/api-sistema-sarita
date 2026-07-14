-- precio_unitario en detalles se asume CON IGV incluido (descompone base + impuesto).
CREATE OR REPLACE FUNCTION ven_crear_comprobante(
    p_id_tipo_comprobante INTEGER,
    p_serie VARCHAR,
    p_numero VARCHAR DEFAULT NULL,
    p_fecha DATE DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_detalles JSON DEFAULT '[]'::JSON,
    p_id_tipo_operacion_sunat INTEGER DEFAULT NULL,
    p_id_comprobante_origen INTEGER DEFAULT NULL,
    p_id_motivo_nota INTEGER DEFAULT NULL,
    p_id_tipo_movimiento INTEGER DEFAULT NULL,
    p_id_tipo_venta INTEGER DEFAULT NULL,
    p_fecha_vencimiento DATE DEFAULT NULL,
    p_tipo_cambio NUMERIC DEFAULT 3.5,
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
    v_id INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
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
    v_sub_total NUMERIC(12,4) := 0;
    v_descuento_total NUMERIC(12,4) := 0;
    v_valor_venta_total NUMERIC(12,4) := 0;
    v_igv_total NUMERIC(12,4) := 0;
    v_total_importe NUMERIC(12,4) := 0;
    v_exonerado_total NUMERIC(12,4) := 0;
    v_id_estado_sunat INTEGER;
    v_id_estado_doc INTEGER;
    v_codigo_tipo VARCHAR;
    v_numero_cuota INTEGER;
    v_id_estado_cuota INTEGER;
    v_serie_origen VARCHAR;
    v_familia_origen CHAR(1);
    v_afecta_stock BOOLEAN;
    v_requiere_stock BOOLEAN := FALSE;
    v_id_tipo_mov_inv INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_nombre_tipo_venta VARCHAR;
    v_stock_disponible NUMERIC(12,4);
    v_mov_result JSON;
    v_glosa_mov VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_serie := UPPER(TRIM(p_serie));

    IF p_id_tipo_comprobante IS NULL THEN
        RETURN json_build_object('error', 'El tipo de comprobante es obligatorio', 'registro', NULL);
    END IF;

    IF v_serie IS NULL OR v_serie = '' THEN
        RETURN json_build_object('error', 'La serie es obligatoria', 'registro', NULL);
    END IF;

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del comprobante es obligatoria', 'registro', NULL);
    END IF;

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF p_detalles IS NULL OR json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
        RETURN json_build_object('error', 'Debe registrar al menos un detalle', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de comprobante indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT lo.descripcion INTO v_codigo_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = p_id_tipo_comprobante;

    -- Serie electrónica SUNAT: 4 caracteres y prefijo según tipo
    IF char_length(v_serie) <> 4 THEN
        RETURN json_build_object(
            'error',
            'La serie electrónica debe tener 4 caracteres (ej. F001, B001, FC01)',
            'registro',
            NULL
        );
    END IF;

    IF v_codigo_tipo = '01' AND left(v_serie, 1) <> 'F' THEN
        RETURN json_build_object('error', 'La factura debe usar serie que inicie con F (ej. F001)', 'registro', NULL);
    END IF;

    IF v_codigo_tipo = '03' AND left(v_serie, 1) <> 'B' THEN
        RETURN json_build_object('error', 'La boleta debe usar serie que inicie con B (ej. B001)', 'registro', NULL);
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND left(v_serie, 1) NOT IN ('F', 'B') THEN
        RETURN json_build_object(
            'error',
            'La nota de crédito/débito debe usar serie que inicie con F o B según el comprobante origen (ej. FC01 / BC01)',
            'registro',
            NULL
        );
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NULL THEN
        RETURN json_build_object('error', 'La nota de crédito/débito requiere el comprobante de origen', 'registro', NULL);
    END IF;

    IF p_id_comprobante_origen IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante_origen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante de origen no existe o está inactivo', 'registro', NULL);
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NOT NULL THEN
        SELECT UPPER(TRIM(serie)) INTO v_serie_origen
        FROM ven_comprobante
        WHERE id = p_id_comprobante_origen AND estado = 1;

        v_familia_origen := left(COALESCE(v_serie_origen, ''), 1);
        IF v_familia_origen IN ('F', 'B') AND left(v_serie, 1) <> v_familia_origen THEN
            RETURN json_build_object(
                'error',
                format(
                    'La serie de la nota debe iniciar con %s igual que el comprobante origen (%s)',
                    v_familia_origen,
                    v_serie_origen
                ),
                'registro',
                NULL
            );
        END IF;
    END IF;

    IF NULLIF(TRIM(p_numero), '') IS NULL THEN
        SELECT (ven_obtener_siguiente_numero(p_id_tipo_comprobante, v_serie)->>'numero')
        INTO v_numero;
    ELSE
        v_numero := LPAD(TRIM(p_numero), 8, '0');
    END IF;

    IF EXISTS (
        SELECT 1 FROM ven_comprobante
        WHERE serie = v_serie AND numero = v_numero AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe un comprobante con la serie ' || v_serie || ' y número ' || v_numero,
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_sunat
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoSunat' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    IF p_id_estado IS NOT NULL THEN
        v_id_estado_doc := p_id_estado;
    ELSE
        SELECT lo.id INTO v_id_estado_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoDocumento' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
        LIMIT 1;
    END IF;

    SELECT lo.id INTO v_id_estado_cuota
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoCuota' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_id_producto := NULLIF((v_detalle->>'id_producto')::INTEGER, 0);
        v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
        v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
        v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
        v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);

        IF v_id_producto IS NULL THEN
            RETURN json_build_object('error', 'Cada detalle debe indicar id_producto', 'registro', NULL);
        END IF;

        IF v_cantidad <= 0 THEN
            RETURN json_build_object('error', 'La cantidad de cada detalle debe ser mayor a cero', 'registro', NULL);
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM pro_producto WHERE id = v_id_producto AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El producto ' || v_id_producto || ' no existe o está inactivo', 'registro', NULL);
        END IF;

        SELECT COALESCE(afecta_stock, FALSE)
        INTO v_afecta_stock
        FROM pro_producto
        WHERE id = v_id_producto;

        IF v_afecta_stock THEN
            v_requiere_stock := TRUE;
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

    IF v_requiere_stock THEN
        IF p_id_almacen IS NULL THEN
            RETURN json_build_object(
                'error',
                'Debe indicar el almacén para descontar stock de los productos',
                'registro',
                NULL
            );
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        SELECT lo.id INTO v_id_tipo_mov_inv
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'SALIDA' AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_mov_inv IS NULL THEN
            RETURN json_build_object(
                'error',
                'No se encontró el tipo de movimiento de inventario SALIDA',
                'registro',
                NULL
            );
        END IF;

        SELECT lo.nombre INTO v_nombre_tipo_venta
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_venta;

        SELECT lo.id INTO v_id_tipo_documento_ref
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoDocumentoRef'
          AND lo.nombre = CASE
            WHEN v_nombre_tipo_venta = 'VENTA_GAS' THEN 'RECARGA'
            WHEN v_codigo_tipo = '01' THEN 'FACTURA'
            WHEN v_codigo_tipo = '03' THEN 'BOLETA'
            WHEN v_codigo_tipo = '07' THEN 'NOTA_CREDITO'
            WHEN v_codigo_tipo = '08' THEN 'NOTA_DEBITO'
            ELSE 'FACTURA'
          END
          AND lo.estado = 1
        LIMIT 1;

        -- Validar disponibilidad antes de crear el comprobante
        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_id_producto := (v_detalle->>'id_producto')::INTEGER;
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);

            SELECT COALESCE(afecta_stock, FALSE)
            INTO v_afecta_stock
            FROM pro_producto
            WHERE id = v_id_producto;

            IF NOT v_afecta_stock THEN
                CONTINUE;
            END IF;

            SELECT COALESCE(s.stock, 0)
            INTO v_stock_disponible
            FROM pro_stock s
            WHERE s.id_almacen = p_id_almacen
              AND s.id_producto = v_id_producto
              AND s.estado = 1;

            IF v_stock_disponible IS NULL THEN
                v_stock_disponible := 0;
            END IF;

            IF v_stock_disponible < v_cantidad THEN
                RETURN json_build_object(
                    'error',
                    format(
                        'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                        v_id_producto,
                        v_stock_disponible,
                        v_cantidad
                    ),
                    'registro',
                    NULL
                );
            END IF;
        END LOOP;
    END IF;

    INSERT INTO ven_comprobante (
        id_tipo_comprobante, serie, numero,
        id_estado_sunat, id_tipo_operacion_sunat,
        id_comprobante_origen, id_motivo_nota,
        id_tipo_movimiento, id_tipo_venta,
        fecha, fecha_vencimiento, tipo_cambio,
        id_cliente, id_sucursal, id_almacen,
        id_condicion_pago, id_moneda, id_medio_pago,
        sub_total, descuento, valor_venta, igv, total_importe,
        exonerado, glosa, observaciones,
        periodo_contable, operacion, id_estado,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_tipo_comprobante, v_serie, v_numero,
        v_id_estado_sunat, p_id_tipo_operacion_sunat,
        p_id_comprobante_origen, p_id_motivo_nota,
        p_id_tipo_movimiento, p_id_tipo_venta,
        p_fecha, p_fecha_vencimiento, COALESCE(p_tipo_cambio, 3.5),
        p_id_cliente, p_id_sucursal, p_id_almacen,
        p_id_condicion_pago, p_id_moneda, p_id_medio_pago,
        v_sub_total, v_descuento_total, v_valor_venta_total, v_igv_total, v_total_importe,
        v_exonerado_total, p_glosa, p_observaciones,
        p_periodo_contable, p_operacion, v_id_estado_doc,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

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
            v_id,
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

    IF v_requiere_stock THEN
        v_glosa_mov := COALESCE(
            NULLIF(TRIM(p_glosa), ''),
            format('Salida por comprobante %s-%s', v_serie, v_numero)
        );

        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_id_producto := (v_detalle->>'id_producto')::INTEGER;
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);

            SELECT COALESCE(afecta_stock, FALSE)
            INTO v_afecta_stock
            FROM pro_producto
            WHERE id = v_id_producto;

            IF NOT v_afecta_stock THEN
                CONTINUE;
            END IF;

            v_mov_result := pro_crear_movimiento(
                p_fecha,
                v_id_producto,
                p_id_almacen,
                v_id_tipo_mov_inv,
                v_cantidad,
                v_id,
                v_id_tipo_documento_ref,
                v_glosa_mov,
                p_id_usuario_auditoria
            );

            IF v_mov_result->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov_result->>'error';
            END IF;
        END LOOP;
    END IF;

    IF p_cuotas IS NOT NULL AND json_typeof(p_cuotas) = 'array' THEN
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
                v_id,
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

    RETURN ven_obtener_comprobante(v_id);
END;
$function$;
