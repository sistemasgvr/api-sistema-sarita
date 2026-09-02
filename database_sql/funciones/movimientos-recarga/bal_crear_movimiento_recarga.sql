CREATE OR REPLACE FUNCTION bal_crear_movimiento_recarga(
    p_fecha_salida_almacen DATE,
    p_id_balon INTEGER,
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
    v_id INTEGER;
    v_id_tipo_recarga INTEGER;
    v_es_empresa BOOLEAN;
    v_capacidad_tipo NUMERIC;
    v_id_estado_recarga_externa INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_id_tipo_doc_recarga INTEGER;
    v_id_tipo_salida INTEGER;
    v_id_tipo_entrada INTEGER;
    v_mov JSON;
    v_obs VARCHAR;
    v_id_producto_gas_balon INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_salida_almacen IS NULL THEN
        RETURN json_build_object('error', 'La fecha de salida de almacén es obligatoria', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT
        COALESCE(prop.nombre, '') = 'EMPRESA',
        COALESCE(tb.capacidad, p_capacidad, 0)
    INTO v_es_empresa, v_capacidad_tipo
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon;

    IF NOT COALESCE(v_es_empresa, FALSE) THEN
        RETURN json_build_object(
            'error',
            'La recarga en planta externa solo aplica a balones de propiedad EMPRESA',
            'registro',
            NULL
        );
    END IF;

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

    SELECT lo.id INTO v_id_tipo_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoRecarga' AND lo.nombre = 'PLANTA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_recarga_externa
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_RECARGA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_salida
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'SALIDA_PLANTA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_entrada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_recarga_externa IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontró el estado EN_RECARGA_EXTERNA del cilindro. Revise el catálogo EstadoBalon.',
            'registro',
            NULL
        );
    END IF;

    IF v_id_estado_en_almacen IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontró el estado EN_ALMACEN del cilindro. Revise el catálogo EstadoBalon.',
            'registro',
            NULL
        );
    END IF;

    IF v_id_tipo_salida IS NULL OR v_id_tipo_entrada IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontraron los tipos SALIDA_PLANTA_EXTERNA / ENTRADA_PLANTA_EXTERNA. Revise el catálogo TipoMovBalon.',
            'registro',
            NULL
        );
    END IF;

    INSERT INTO bal_movimiento_recarga (
        fecha_salida_almacen, id_balon, id_tipo_recarga, id_producto, capacidad, id_unidad_medida,
        serie_guia_salida, numero_guia_salida, serie_guia_ingreso, numero_guia_ingreso,
        serie_factura, numero_factura, id_comprobante, id_comprobante_compra, fecha_llegada_almacen,
        lote, fecha_vencimiento_lote, fecha_prueba_hidrostatica, id_proveedor,
        observacion, id_almacen,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_fecha_salida_almacen, p_id_balon, v_id_tipo_recarga, p_id_producto, p_capacidad, p_id_unidad_medida,
        p_serie_guia_salida, p_numero_guia_salida, p_serie_guia_ingreso, p_numero_guia_ingreso,
        p_serie_factura, p_numero_factura, p_id_comprobante, p_id_comprobante_compra, p_fecha_llegada_almacen,
        p_lote, p_fecha_vencimiento_lote, p_fecha_prueba_hidrostatica, p_id_proveedor,
        p_observacion, p_id_almacen,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    v_obs := COALESCE(NULLIF(TRIM(p_observacion), ''), 'Recarga planta externa');

    -- Libro de movimientos: salida a planta.
    v_mov := inv_registrar_movimiento(
        p_naturaleza                => 'BALON',
        p_codigo_tipo_movimiento    => 'SALIDA_PLANTA_EXTERNA',
        p_fecha                     => p_fecha_salida_almacen::TIMESTAMP,
        p_id_producto               => NULL,
        p_id_balon                  => p_id_balon,
        p_cantidad                  => 1,
        p_id_almacen_origen         => p_id_almacen,
        p_id_almacen_destino        => NULL,
        p_id_cliente                => p_id_proveedor,
        p_codigo_tipo_documento_origen => 'RECARGA',
        p_id_documento_origen       => v_id,
        p_glosa                     => v_obs,
        p_id_usuario_auditoria      => p_id_usuario_auditoria
    );
    IF v_mov->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
    END IF;

    IF p_fecha_llegada_almacen IS NOT NULL THEN
        -- inv_registrar_movimiento ya actualizó id_estado_balon a EN_ALMACEN.
        -- Solo fijamos id_producto_gas.
        UPDATE bal_balon
        SET
            id_producto_gas = COALESCE(p_id_producto, id_producto_gas),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1
        RETURNING id_producto_gas INTO v_id_producto_gas_balon;

        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'ENTRADA_PLANTA_EXTERNA',
            p_fecha                     => p_fecha_llegada_almacen::TIMESTAMP,
            p_id_producto               => v_id_producto_gas_balon,
            p_id_balon                  => p_id_balon,
            p_cantidad                  => COALESCE(p_capacidad, NULLIF(v_capacidad_tipo, 0), 1),
            p_id_almacen_origen         => NULL,
            p_id_almacen_destino        => p_id_almacen,
            p_id_cliente                => p_id_proveedor,
            p_codigo_tipo_documento_origen => 'RECARGA',
            p_id_documento_origen       => v_id,
            p_glosa                     => v_obs,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
        IF v_mov->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
        END IF;
    ELSE
        -- inv_registrar_movimiento (SALIDA_PLANTA_EXTERNA) ya puso EN_RECARGA_EXTERNA + limpió almacén.
        NULL;
    END IF;

    RETURN bal_obtener_movimiento_recarga(v_id);
END;
$function$;
