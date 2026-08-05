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

    IF p_fecha_llegada_almacen IS NOT NULL THEN
        UPDATE bal_balon
        SET
            id_producto_gas = COALESCE(p_id_producto, id_producto_gas),
            id_estado_contenido = COALESCE(bal_id_estado_contenido('LLENO'), id_estado_contenido),
            capacidad_restante = COALESCE(NULLIF(v_capacidad_tipo, 0), p_capacidad, capacidad_restante),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    ELSE
        -- Salida a planta: queda vacío sin residual.
        UPDATE bal_balon
        SET
            id_estado_contenido = COALESCE(bal_id_estado_contenido('VACIO'), id_estado_contenido),
            capacidad_restante = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    END IF;

    RETURN bal_obtener_movimiento_recarga(v_id);
END;
$function$;
