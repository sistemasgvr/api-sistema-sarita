DROP FUNCTION IF EXISTS bal_crear_recarga_cliente(
    INTEGER, INTEGER, INTEGER, NUMERIC, NUMERIC, INTEGER, VARCHAR, NUMERIC,
    INTEGER, INTEGER, VARCHAR, INTEGER, INTEGER
);

CREATE OR REPLACE FUNCTION bal_crear_recarga_cliente(
    p_id_cliente INTEGER,
    p_id_balon INTEGER,
    p_id_producto INTEGER,
    p_precio_unitario NUMERIC,
    p_cantidad NUMERIC DEFAULT 1,
    p_id_tipo_comprobante INTEGER DEFAULT NULL,
    p_serie VARCHAR DEFAULT 'B001',
    p_capacidad NUMERIC DEFAULT NULL,
    p_id_medio_pago INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_balon_origen INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_id_condicion_pago INTEGER DEFAULT NULL,
    p_fecha_vencimiento DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_id_tipo_recarga INTEGER;
    v_id_tipo_comprobante INTEGER;
    v_id_tipo_venta INTEGER;
    v_id_afectacion_igv INTEGER;
    v_id_tipo_movimiento INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_id_moneda INTEGER;
    v_id_tipo_operacion_sunat INTEGER;
    v_detalles JSON;
    v_comprobante_result JSON;
    v_id_comprobante INTEGER;
    v_serie_comprobante VARCHAR;
    v_numero_comprobante VARCHAR;
    v_id_recarga INTEGER;
    v_recarga JSON;
    v_comprobante JSON;
    v_capacidad NUMERIC;
    v_capacidad_destino NUMERIC;
    v_producto_nombre VARCHAR;
    v_consumo JSON;
    v_asignacion JSON;
    v_origenes JSON;
    v_id_balon_origen_principal INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := CURRENT_DATE;

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'El balón es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_balon_origen IS NOT NULL AND p_id_balon_origen = p_id_balon THEN
        RETURN json_build_object(
            'error',
            'El balón origen no puede ser el mismo que el destino',
            'registro',
            NULL
        );
    END IF;

    IF p_id_producto IS NULL THEN
        RETURN json_build_object('error', 'El producto (gas) es obligatorio', 'registro', NULL);
    END IF;

    IF p_precio_unitario IS NULL OR p_precio_unitario < 0 THEN
        RETURN json_build_object('error', 'El precio unitario es obligatorio', 'registro', NULL);
    END IF;

    IF COALESCE(p_cantidad, 0) <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
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
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoRecarga' AND lo.nombre = 'CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF p_id_tipo_comprobante IS NOT NULL THEN
        v_id_tipo_comprobante := p_id_tipo_comprobante;
    ELSE
        SELECT lo.id INTO v_id_tipo_comprobante
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoComprobante' AND lo.nombre = 'BOLETA' AND lo.estado = 1
        LIMIT 1;
    END IF;

    IF v_id_tipo_comprobante IS NULL THEN
        RETURN json_build_object('error', 'No se encontró el tipo de comprobante BOLETA en catálogos', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_venta
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoVenta' AND lo.nombre = 'VENTA_GAS' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_afectacion_igv
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'AfectacionIgv' AND lo.descripcion = '10' AND lo.estado = 1
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
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_LLENADO' AND lo.estado = 1
        LIMIT 1;
    END IF;

    SELECT lo.id INTO v_id_tipo_documento_ref
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_moneda
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'Moneda' AND lo.nombre = 'PEN' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_operacion_sunat
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoOperacionSunat' AND lo.descripcion = '0101' AND lo.estado = 1
    LIMIT 1;

    SELECT nombre INTO v_producto_nombre
    FROM pro_producto
    WHERE id = p_id_producto;

    SELECT COALESCE(tb.capacidad, p_capacidad, p_cantidad, 0)
    INTO v_capacidad_destino
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon;

    v_capacidad := COALESCE(NULLIF(p_capacidad, 0), v_capacidad_destino, p_cantidad);

    IF v_capacidad <= 0 THEN
        RETURN json_build_object(
            'error',
            'No se pudo determinar la capacidad a recargar',
            'registro',
            NULL
        );
    END IF;

    v_asignacion := bal_asignar_origenes_recarga(
        p_id_producto,
        v_capacidad,
        p_id_almacen,
        p_id_balon_origen
    );

    IF v_asignacion->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_asignacion->>'error', 'registro', NULL);
    END IF;

    v_origenes := v_asignacion->'origenes';
    v_id_balon_origen_principal := (v_asignacion->>'id_balon_origen_principal')::INTEGER;

    v_detalles := json_build_array(
        json_build_object(
            'id_producto', p_id_producto,
            'cantidad', p_cantidad,
            'precio_unitario', p_precio_unitario,
            'descuento', 0,
            'porcentaje_igv', 18,
            'id_afectacion_igv', v_id_afectacion_igv,
            'descripcion', 'Recarga ' || COALESCE(v_producto_nombre, 'gas'),
            'id_balon', p_id_balon,
            'capacidad_cilindro', v_capacidad
        )
    );

    v_comprobante_result := ven_crear_comprobante(
        v_id_tipo_comprobante,
        COALESCE(NULLIF(TRIM(p_serie), ''), 'B001'),
        NULL,
        v_fecha,
        p_id_cliente,
        v_detalles,
        v_id_tipo_operacion_sunat,
        NULL,
        NULL,
        NULL,
        v_id_tipo_venta,
        p_fecha_vencimiento,
        3.5,
        NULL,
        p_id_almacen,
        p_id_condicion_pago,
        v_id_moneda,
        p_id_medio_pago,
        'Recarga de balón',
        p_observacion,
        NULL,
        NULL,
        NULL,
        NULL,
        p_id_usuario_auditoria,
        'recarga'
    );

    IF v_comprobante_result->>'error' IS NOT NULL THEN
        RETURN json_build_object(
            'error', v_comprobante_result->>'error',
            'registro', NULL
        );
    END IF;

    v_comprobante := v_comprobante_result->'registro';
    v_id_comprobante := (v_comprobante->>'id')::INTEGER;
    v_serie_comprobante := v_comprobante->>'serie';
    v_numero_comprobante := v_comprobante->>'numero';

    v_consumo := bal_consumir_capacidad_origenes_recarga(
        v_origenes,
        p_id_usuario_auditoria
    );

    IF v_consumo->>'error' IS NOT NULL THEN
        -- Abortar para revertir el comprobante ya creado en la misma transacción.
        RAISE EXCEPTION '%', v_consumo->>'error';
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
        v_id_balon_origen_principal,
        p_id_cliente,
        v_id_tipo_recarga,
        p_id_producto,
        v_capacidad,
        v_serie_comprobante,
        v_numero_comprobante,
        v_id_comprobante,
        v_fecha,
        CASE
            WHEN COALESCE(v_asignacion->>'etiqueta', '') <> '' THEN
                TRIM(BOTH ' ' FROM CONCAT_WS(
                    ' | ',
                    NULLIF(TRIM(COALESCE(p_observacion, '')), ''),
                    'Orígenes: ' || (v_asignacion->>'etiqueta')
                ))
            ELSE p_observacion
        END,
        p_id_almacen,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_recarga;

    INSERT INTO bal_movimiento_recarga_origen (
        id_movimiento_recarga,
        id_balon,
        cantidad,
        orden,
        id_usuario_creacion
    )
    SELECT
        v_id_recarga,
        (o->>'id_balon')::INTEGER,
        (o->>'cantidad')::NUMERIC,
        COALESCE((o->>'orden')::INTEGER, 1),
        p_id_usuario_auditoria
    FROM json_array_elements(v_origenes) o;

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
            COALESCE(p_observacion, 'Recarga cliente'),
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
        id_estado_balon = COALESCE(
            (
                SELECT lo.id
                FROM gen_lista_opciones lo
                INNER JOIN gen_lista l ON lo.id_lista = l.id
                WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_PODER_CLIENTE' AND lo.estado = 1
                LIMIT 1
            ),
            id_estado_balon
        ),
        id_estado_contenido = COALESCE(bal_id_estado_contenido('DESCONOCIDO'), id_estado_contenido),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    PERFORM bal_sync_capacidad_restante(
        p_id_balon,
        NULL,
        NULL,
        NULL,
        'CLEAR',
        NULL,
        p_id_usuario_auditoria
    );

    v_recarga := bal_obtener_movimiento_recarga(v_id_recarga);

    RETURN json_build_object(
        'registro', json_build_object(
            'recarga', v_recarga->'registro',
            'comprobante', v_comprobante
        )
    );
END;
$function$;
