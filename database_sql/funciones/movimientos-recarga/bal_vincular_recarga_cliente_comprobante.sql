CREATE OR REPLACE FUNCTION bal_vincular_recarga_cliente_comprobante(
    p_id_comprobante INTEGER,
    p_id_cliente INTEGER,
    p_id_balon INTEGER,
    p_id_producto INTEGER,
    p_capacidad NUMERIC DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_balon_origen INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_id_tipo_recarga INTEGER;
    v_id_tipo_movimiento INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_id_recarga INTEGER;
    v_serie_comprobante VARCHAR;
    v_numero_comprobante VARCHAR;
    v_capacidad NUMERIC;
    v_capacidad_destino NUMERIC;
    v_recarga JSON;
    v_consumo JSON;
    v_origen_ok BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := CURRENT_DATE;

    IF p_id_comprobante IS NULL THEN
        RETURN json_build_object('error', 'El comprobante es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'El balón es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_producto IS NULL THEN
        RETURN json_build_object('error', 'El producto (gas) es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_balon_origen IS NULL THEN
        RETURN json_build_object(
            'error',
            'Debe indicar el balón empresa origen de la recarga',
            'registro',
            NULL
        );
    END IF;

    IF p_id_balon_origen = p_id_balon THEN
        RETURN json_build_object(
            'error',
            'El balón origen no puede ser el mismo que el destino',
            'registro',
            NULL
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1 AND es_gas = TRUE
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no es un gas activo', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_movimiento_recarga
        WHERE id_comprobante = p_id_comprobante
          AND id_balon = p_id_balon
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'Ya existe una recarga vinculada a este comprobante y balón',
            'registro',
            NULL
        );
    END IF;

    SELECT
        COALESCE(tb.capacidad, p_capacidad, 0)
    INTO v_capacidad_destino
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon;

    v_capacidad := COALESCE(NULLIF(p_capacidad, 0), v_capacidad_destino, 0);

    IF v_capacidad <= 0 THEN
        RETURN json_build_object(
            'error',
            'No se pudo determinar la capacidad a recargar',
            'registro',
            NULL
        );
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        LEFT JOIN gen_lista_opciones ec ON ec.id = b.id_estado_contenido
        WHERE b.id = p_id_balon_origen
          AND b.estado = 1
          AND COALESCE(prop.nombre, '') = 'EMPRESA'
          AND COALESCE(eb.nombre, '') = 'EN_ALMACEN'
          AND COALESCE(ec.nombre, '') = 'LLENO'
          AND b.id_producto_gas = p_id_producto
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen OR b.id_almacen IS NULL)
          AND bal_capacidad_disponible_balon(b.id) >= v_capacidad
    ) INTO v_origen_ok;

    IF NOT COALESCE(v_origen_ok, FALSE) THEN
        RETURN json_build_object(
            'error',
            'No hay balón empresa LLENO válido del mismo gas con capacidad suficiente (origen inválido o sin stock físico)',
            'registro',
            NULL
        );
    END IF;

    SELECT lo.id INTO v_id_tipo_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoRecarga' AND lo.nombre = 'CLIENTE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_movimiento
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'RECARGA_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_movimiento IS NULL THEN
        SELECT lo.id INTO v_id_tipo_movimiento
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'RECARGA' AND lo.estado = 1
        LIMIT 1;
    END IF;

    SELECT lo.id INTO v_id_tipo_documento_ref
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    SELECT serie, numero INTO v_serie_comprobante, v_numero_comprobante
    FROM ven_comprobante
    WHERE id = p_id_comprobante;

    v_consumo := bal_consumir_capacidad_balon_origen(
        p_id_balon_origen,
        v_capacidad,
        p_id_usuario_auditoria
    );

    IF v_consumo->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_consumo->>'error', 'registro', NULL);
    END IF;

    INSERT INTO bal_movimiento_recarga (
        fecha_salida_almacen,
        id_balon,
        id_balon_origen,
        id_cliente,
        id_tipo_recarga,
        id_producto,
        capacidad,
        serie_factura,
        numero_factura,
        id_comprobante,
        fecha_llegada_almacen,
        observacion,
        id_almacen,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        v_fecha,
        p_id_balon,
        p_id_balon_origen,
        p_id_cliente,
        v_id_tipo_recarga,
        p_id_producto,
        v_capacidad,
        v_serie_comprobante,
        v_numero_comprobante,
        p_id_comprobante,
        v_fecha,
        p_observacion,
        p_id_almacen,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_recarga;

    IF v_id_tipo_movimiento IS NOT NULL THEN
        INSERT INTO bal_movimiento (
            id_balon,
            id_tipo_movimiento,
            id_documento_ref,
            id_tipo_documento_ref,
            id_cliente,
            id_almacen_destino,
            fecha_movimiento,
            observacion,
            id_usuario_creacion,
            id_usuario_modificacion
        )
        VALUES (
            p_id_balon,
            v_id_tipo_movimiento,
            v_id_recarga,
            v_id_tipo_documento_ref,
            p_id_cliente,
            p_id_almacen,
            NOW(),
            COALESCE(p_observacion, 'Recarga cliente (POS)'),
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END IF;

    -- Sale lleno del mostrador, pero fuera de planta el residual deja de ser confiable.
    UPDATE bal_balon
    SET
        id_producto_gas = p_id_producto,
        id_cliente_ubicacion = p_id_cliente,
        id_almacen = NULL,
        presion_actual = NULL,
        id_estado_contenido = COALESCE(bal_id_estado_contenido('DESCONOCIDO'), id_estado_contenido),
        capacidad_restante = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    v_recarga := bal_obtener_movimiento_recarga(v_id_recarga);

    RETURN json_build_object('registro', v_recarga->'registro');
END;
$function$;
