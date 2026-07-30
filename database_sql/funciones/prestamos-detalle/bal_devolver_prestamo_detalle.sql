CREATE OR REPLACE FUNCTION bal_devolver_prestamo_detalle(
    p_id INTEGER,
    p_fecha_devolucion DATE DEFAULT CURRENT_DATE,
    p_id_almacen_destino INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_prestamo INTEGER;
    v_id_balon INTEGER;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_fecha_devolucion DATE;
    v_id_almacen_destino INTEGER;
    v_id_tipo_movimiento INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_id_estado_detalle_devuelto INTEGER;
    v_id_estado_cerrado INTEGER;
    v_mov_result JSON;
    v_pendientes INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        pd.id_prestamo,
        pd.id_balon,
        pd.fecha_devolucion,
        p.id_cliente,
        p.id_almacen
    INTO
        v_id_prestamo,
        v_id_balon,
        v_fecha_devolucion,
        v_id_cliente,
        v_id_almacen
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE pd.id = p_id
      AND pd.estado = 1;

    IF v_id_prestamo IS NULL THEN
        RETURN json_build_object(
            'error', 'El detalle de préstamo no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF v_fecha_devolucion IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'El cilindro ya fue registrado como devuelto',
            'registro', NULL
        );
    END IF;

    v_id_almacen_destino := COALESCE(p_id_almacen_destino, v_id_almacen);

    IF v_id_balon IS NOT NULL AND v_id_almacen_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'Debe indicar el almacén de destino de la devolución',
            'registro', NULL
        );
    END IF;

    IF v_id_almacen_destino IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_destino AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'El almacén de destino no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_tipo_movimiento
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_DEVOLUCION' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_documento_ref
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'PRESTAMO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_detalle_devuelto
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamoDetalle' AND lo.nombre = 'DEVUELTO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_cerrado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamo' AND lo.nombre = 'CERRADO' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_prestamo_detalle
    SET
        fecha_devolucion = COALESCE(p_fecha_devolucion, CURRENT_DATE),
        id_estado = COALESCE(v_id_estado_detalle_devuelto, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND estado = 1;

    IF v_id_balon IS NOT NULL AND v_id_tipo_movimiento IS NOT NULL THEN
        v_mov_result := bal_crear_movimiento(
            v_id_balon,
            v_id_tipo_movimiento,
            v_id_prestamo,
            v_id_tipo_documento_ref,
            v_id_cliente,
            NULL,
            v_id_almacen_destino,
            NOW(),
            'Entrada por devolución de préstamo',
            p_id_usuario_auditoria
        );

        IF v_mov_result->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov_result->>'error';
        END IF;

        UPDATE bal_balon
        SET
            id_cliente_ubicacion = NULL,
            id_almacen = v_id_almacen_destino,
            id_estado_balon = COALESCE(v_id_estado_en_almacen, id_estado_balon),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon
          AND estado = 1;
    END IF;

    SELECT COUNT(*) INTO v_pendientes
    FROM bal_prestamo_detalle
    WHERE id_prestamo = v_id_prestamo
      AND estado = 1
      AND fecha_devolucion IS NULL;

    IF v_pendientes = 0 THEN
        UPDATE bal_prestamo
        SET
            fecha_retorno_real = COALESCE(
                fecha_retorno_real,
                COALESCE(p_fecha_devolucion, CURRENT_DATE)
            ),
            id_estado = COALESCE(v_id_estado_cerrado, id_estado),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_prestamo
          AND estado = 1;
    END IF;

    RETURN bal_obtener_prestamo_detalle(p_id);
END;
$function$;
