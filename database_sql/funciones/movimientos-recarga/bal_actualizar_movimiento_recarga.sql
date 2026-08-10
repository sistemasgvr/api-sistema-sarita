CREATE OR REPLACE FUNCTION bal_actualizar_movimiento_recarga(
    p_id INTEGER,
    p_fecha_salida_almacen DATE DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_capacidad NUMERIC DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_serie_guia_salida VARCHAR DEFAULT NULL,
    p_numero_guia_salida VARCHAR DEFAULT NULL,
    p_serie_guia_ingreso VARCHAR DEFAULT NULL,
    p_numero_guia_ingreso VARCHAR DEFAULT NULL,
    p_serie_factura VARCHAR DEFAULT NULL,
    p_numero_factura VARCHAR DEFAULT NULL,
    p_id_comprobante INTEGER DEFAULT NULL,
    p_fecha_llegada_almacen DATE DEFAULT NULL,
    p_lote VARCHAR DEFAULT NULL,
    p_fecha_vencimiento_lote DATE DEFAULT NULL,
    p_fecha_prueba_hidrostatica DATE DEFAULT NULL,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_comprobante_compra INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_fecha_llegada_antes DATE;
    v_fecha_llegada DATE;
    v_id_producto INTEGER;
    v_id_almacen INTEGER;
    v_capacidad_tipo NUMERIC;
    v_id_estado_en_almacen INTEGER;
    v_id_tipo_doc_recarga INTEGER;
    v_id_tipo_entrada INTEGER;
    v_mov JSON;
    v_obs VARCHAR;
    v_ya_tiene_entrada BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante_compra IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante_compra AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'El comprobante de compra indicado no existe o está inactivo',
            'registro',
            NULL
        );
    END IF;

    SELECT fecha_llegada_almacen
    INTO v_fecha_llegada_antes
    FROM bal_movimiento_recarga
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE bal_movimiento_recarga
    SET
        fecha_salida_almacen = COALESCE(p_fecha_salida_almacen, fecha_salida_almacen),
        id_producto = COALESCE(p_id_producto, id_producto),
        capacidad = COALESCE(p_capacidad, capacidad),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        serie_guia_salida = COALESCE(p_serie_guia_salida, serie_guia_salida),
        numero_guia_salida = COALESCE(p_numero_guia_salida, numero_guia_salida),
        serie_guia_ingreso = COALESCE(p_serie_guia_ingreso, serie_guia_ingreso),
        numero_guia_ingreso = COALESCE(p_numero_guia_ingreso, numero_guia_ingreso),
        serie_factura = COALESCE(p_serie_factura, serie_factura),
        numero_factura = COALESCE(p_numero_factura, numero_factura),
        id_comprobante = COALESCE(p_id_comprobante, id_comprobante),
        id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        fecha_llegada_almacen = COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen),
        lote = COALESCE(p_lote, lote),
        fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
        fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        observacion = COALESCE(p_observacion, observacion),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1
    RETURNING id_balon, fecha_llegada_almacen, id_producto, id_almacen, observacion
    INTO v_id_balon, v_fecha_llegada, v_id_producto, v_id_almacen, v_obs;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_fecha_llegada IS NOT NULL AND v_id_balon IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NULL THEN
            RETURN json_build_object(
                'error',
                'No se encontró el estado EN_ALMACEN del cilindro. Revise el catálogo EstadoBalon.',
                'registro',
                NULL
            );
        END IF;

        SELECT COALESCE(tb.capacidad, p_capacidad, 0)
        INTO v_capacidad_tipo
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        WHERE b.id = v_id_balon;

        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_en_almacen,
            id_producto_gas = COALESCE(v_id_producto, id_producto_gas),
            id_estado_contenido = COALESCE(bal_id_estado_contenido('LLENO'), id_estado_contenido),
            capacidad_restante = COALESCE(NULLIF(v_capacidad_tipo, 0), p_capacidad, capacidad_restante),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon AND estado = 1;

        -- Primera vez que se registra llegada: movimiento de entrada.
        IF v_fecha_llegada_antes IS NULL THEN
            SELECT lo.id INTO v_id_tipo_doc_recarga
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
            LIMIT 1;

            SELECT lo.id INTO v_id_tipo_entrada
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_entrada IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontró el tipo ENTRADA_PLANTA_EXTERNA. Revise el catálogo TipoMovBalon.',
                    'registro',
                    NULL
                );
            END IF;

            SELECT EXISTS (
                SELECT 1
                FROM bal_movimiento m
                WHERE m.estado = 1
                  AND m.id_balon = v_id_balon
                  AND m.id_documento_ref = p_id
                  AND m.id_tipo_movimiento = v_id_tipo_entrada
            ) INTO v_ya_tiene_entrada;

            IF NOT COALESCE(v_ya_tiene_entrada, FALSE) THEN
                v_mov := bal_crear_movimiento(
                    v_id_balon,
                    v_id_tipo_entrada,
                    p_id,
                    v_id_tipo_doc_recarga,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    v_id_almacen,
                    v_fecha_llegada::TIMESTAMP,
                    COALESCE(NULLIF(TRIM(v_obs), ''), 'Retorno planta externa'),
                    p_id_usuario_auditoria
                );
                IF v_mov->>'error' IS NOT NULL THEN
                    RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
                END IF;
            END IF;
        END IF;
    END IF;

    RETURN bal_obtener_movimiento_recarga(p_id);
END;
$function$;
