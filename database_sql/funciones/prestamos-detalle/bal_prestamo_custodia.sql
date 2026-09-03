-- Helpers de custodia para préstamos: salida, retorno y cierre de cabecera.
-- Fuente de verdad del cilindro = Libro (estado / almacén / cliente / gas / contenido).

CREATE OR REPLACE FUNCTION bal_prestamo_cerrar_si_completo(
    p_id_prestamo INTEGER,
    p_fecha DATE DEFAULT CURRENT_DATE,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_pendientes INTEGER;
    v_id_estado_cerrado INTEGER;
BEGIN
    IF p_id_prestamo IS NULL THEN
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_pendientes
    FROM bal_prestamo_detalle
    WHERE id_prestamo = p_id_prestamo
      AND estado = 1
      AND fecha_devolucion IS NULL;

    IF COALESCE(v_pendientes, 0) > 0 THEN
        RETURN;
    END IF;

    SELECT lo.id INTO v_id_estado_cerrado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamo' AND lo.nombre = 'CERRADO' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_prestamo
    SET
        fecha_retorno_real = COALESCE(fecha_retorno_real, COALESCE(p_fecha, CURRENT_DATE)),
        id_estado = COALESCE(v_id_estado_cerrado, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_prestamo
      AND estado = 1;
END;
$function$;

CREATE OR REPLACE FUNCTION bal_prestamo_aplicar_salida_cilindro(
    p_id_prestamo INTEGER,
    p_id_balon INTEGER,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_id_comprobante INTEGER;
    v_id_almacen_origen INTEGER;
    v_nombre_estado VARCHAR;
    v_id_estado_prestado INTEGER;
    v_codigo_tipo_comp VARCHAR;
    v_id_documento_ref INTEGER;
    v_codigo_tipo_doc_ref VARCHAR;
    v_mov JSON;
    v_custodia BOOLEAN := FALSE;
BEGIN
    IF p_id_prestamo IS NULL OR p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'Préstamo y cilindro son obligatorios', 'ok', FALSE);
    END IF;

    SELECT p.id_cliente, p.id_comprobante_venta
    INTO v_id_cliente, v_id_comprobante
    FROM bal_prestamo p
    WHERE p.id = p_id_prestamo AND p.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'ok', FALSE);
    END IF;

    SELECT b.id_almacen, eb.nombre
    INTO v_id_almacen_origen, v_nombre_estado
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'ok', FALSE);
    END IF;

    IF COALESCE(v_nombre_estado, '') IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'error', 'No se puede prestar un cilindro dado de baja o reportado como robo',
            'ok', FALSE
        );
    END IF;

    IF COALESCE(v_nombre_estado, '') IN (
        'ALQUILADO', 'EN_MANTENIMIENTO', 'EN_RECARGA_EXTERNA', 'POR_RECOGER', 'EN_PODER_CLIENTE'
    ) THEN
        RETURN json_build_object(
            'error',
            format('El cilindro está %s; no se puede prestar', LOWER(REPLACE(v_nombre_estado, '_', ' '))),
            'ok', FALSE
        );
    END IF;

    SELECT lo.id INTO v_id_estado_prestado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_prestado IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado PRESTADO_CLIENTE del cilindro. Revise el catálogo EstadoBalon.',
            'ok', FALSE
        );
    END IF;

    IF v_id_comprobante IS NOT NULL THEN
        SELECT lo.descripcion INTO v_codigo_tipo_comp
        FROM ven_comprobante c
        INNER JOIN gen_lista_opciones lo ON lo.id = c.id_tipo_comprobante
        WHERE c.id = v_id_comprobante AND c.estado = 1;

        v_id_documento_ref := v_id_comprobante;
        v_codigo_tipo_doc_ref := CASE
            WHEN v_codigo_tipo_comp = '01' THEN 'FACTURA'
            WHEN v_codigo_tipo_comp = '03' THEN 'BOLETA'
            WHEN v_codigo_tipo_comp IN ('NV', 'VSD') THEN 'NOTA_VENTA'
            ELSE 'FACTURA'
        END;
    ELSE
        v_id_documento_ref := p_id_prestamo;
        v_codigo_tipo_doc_ref := 'PRESTAMO';
    END IF;

    v_mov := bal_registrar_salida_documento(
        p_id_balon,
        'SALIDA_PRESTAMO',
        v_id_documento_ref,
        v_codigo_tipo_doc_ref,
        v_id_cliente,
        v_id_almacen_origen,
        'PRESTADO_CLIENTE',
        TRUE,
        NULL,
        COALESCE(NULLIF(TRIM(p_observacion), ''), 'Salida automática por préstamo'),
        p_id_usuario_auditoria
    );

    IF v_mov->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_mov->>'error', 'ok', FALSE);
    END IF;

    IF COALESCE(v_nombre_estado, '') IN ('EN_ALMACEN', '', 'PRESTADO_CLIENTE', 'EN_RUTA_LIMA')
       OR v_nombre_estado IS NULL
    THEN
        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_prestado,
            id_cliente_ubicacion = COALESCE(v_id_cliente, id_cliente_ubicacion),
            id_almacen = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    END IF;

    IF COALESCE(v_nombre_estado, '') = 'EN_ALMACEN' THEN
        v_custodia := TRUE;
    END IF;

    RETURN json_build_object('ok', TRUE, 'custodia_actualizada', v_custodia);
END;
$function$;

CREATE OR REPLACE FUNCTION bal_prestamo_aplicar_retorno_cilindro(
    p_id_balon INTEGER,
    p_id_prestamo INTEGER,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_almacen_destino INTEGER DEFAULT NULL,
    p_nombre_contenido VARCHAR DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_crear_movimiento BOOLEAN DEFAULT TRUE
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre_estado VARCHAR;
    v_id_almacen INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_contenido VARCHAR;
    v_capacidad NUMERIC;
    v_mov JSON;
    v_en_campo BOOLEAN := FALSE;
BEGIN
    IF p_id_balon IS NULL THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    SELECT eb.nombre, b.id_almacen, tb.capacidad
    INTO v_nombre_estado, v_id_almacen, v_capacidad
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'ok', FALSE);
    END IF;

    v_en_campo := COALESCE(v_nombre_estado, '') IN (
        'PRESTADO_CLIENTE', 'POR_RECOGER', 'EN_PODER_CLIENTE', 'EN_RUTA_LIMA'
    ) OR (COALESCE(v_nombre_estado, '') = 'EN_ALMACEN' AND v_id_almacen IS NULL);

    -- Ya está en almacén (p. ej. volvió por otro flujo): no pisar contenido/stock.
    IF COALESCE(v_nombre_estado, '') = 'EN_ALMACEN' AND v_id_almacen IS NOT NULL THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    -- Custodia de otro proceso (alquiler / recarga / taller): solo se cierra el préstamo.
    IF COALESCE(v_nombre_estado, '') IN (
        'ALQUILADO', 'EN_MANTENIMIENTO', 'EN_RECARGA_EXTERNA', 'DADO_DE_BAJA', 'ROBO'
    ) THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    IF NOT v_en_campo AND COALESCE(v_nombre_estado, '') <> '' THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    IF p_id_almacen_destino IS NULL THEN
        RETURN json_build_object('error', 'Debe indicar el almacén de destino de la devolución', 'ok', FALSE);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén de destino no existe o está inactivo', 'ok', FALSE);
    END IF;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_en_almacen IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado EN_ALMACEN del cilindro. Revise el catálogo EstadoBalon.',
            'ok', FALSE
        );
    END IF;

    IF p_crear_movimiento THEN
        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'ENTRADA_DEVOLUCION',
            p_fecha                     => LOCALTIMESTAMP,
            p_id_balon                  => p_id_balon,
            p_cantidad                  => 1,
            p_id_almacen_destino        => p_id_almacen_destino,
            p_id_cliente                => p_id_cliente,
            p_codigo_tipo_documento_origen => 'PRESTAMO',
            p_id_documento_origen       => p_id_prestamo,
            p_glosa                     => COALESCE(NULLIF(TRIM(p_observacion), ''), 'Entrada por devolución de préstamo'),
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );

        IF v_mov->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_mov->>'error', 'ok', FALSE);
        END IF;
    END IF;

    UPDATE bal_balon
    SET
        id_cliente_ubicacion = NULL,
        id_almacen = p_id_almacen_destino,
        id_estado_balon = v_id_estado_en_almacen,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    RETURN json_build_object('ok', TRUE, 'skipped', FALSE);
END;
$function$;
