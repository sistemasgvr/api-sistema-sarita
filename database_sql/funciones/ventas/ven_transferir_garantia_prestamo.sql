-- Transfiere una garantía activa de un préstamo renovado al préstamo nuevo
DROP FUNCTION IF EXISTS public.ven_transferir_garantia_prestamo (
  p_id_garantia integer,
  p_id_prestamo_destino integer,
  p_id_prestamo_detalle integer,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.ven_transferir_garantia_prestamo (
  p_id_garantia integer,
  p_id_prestamo_destino integer,
  p_id_prestamo_detalle integer DEFAULT NULL::integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_garantia RECORD;
    v_id_estado_transferida INTEGER;
    v_id_estado_activa INTEGER;
    v_id_tipo_transferencia INTEGER;
    v_id_sucursal INTEGER;
    v_monto NUMERIC(12,4);
    v_id_nueva INTEGER;
    v_numero_prestamo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_garantia IS NULL OR p_id_prestamo_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'La garantía y el préstamo destino son obligatorios',
            'registro', NULL
        );
    END IF;

    SELECT g.* INTO v_garantia
    FROM ven_garantia g
    WHERE g.id = p_id_garantia AND g.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La garantía indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    v_monto := COALESCE(v_garantia.monto_saldo, 0);

    IF v_monto <= 0 THEN
        RETURN json_build_object(
            'error', 'La garantía no tiene saldo por transferir',
            'registro', NULL
        );
    END IF;

    SELECT p.numero_prestamo, a.id_sucursal
    INTO v_numero_prestamo, v_id_sucursal
    FROM bal_prestamo p
    LEFT JOIN gen_almacen a ON a.id = p.id_almacen
    WHERE p.id = p_id_prestamo_destino AND p.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'error', 'El préstamo destino no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF p_id_prestamo_detalle IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_prestamo_detalle pd
        WHERE pd.id = p_id_prestamo_detalle
          AND pd.id_prestamo = p_id_prestamo_destino
          AND pd.estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'El detalle indicado no pertenece al préstamo destino',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_transferida
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGarantia' AND lo.nombre = 'TRANSFERIDA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_transferida IS NULL THEN
        RETURN json_build_object('error', 'Falta opción EstadoGarantia.TRANSFERIDA en catálogo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado_activa
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGarantia' AND lo.nombre = 'ACTIVA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_activa IS NULL THEN
        RETURN json_build_object('error', 'Falta opción EstadoGarantia.ACTIVA en catálogo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_transferencia
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'TRANSFERENCIA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_transferencia IS NULL THEN
        RETURN json_build_object('error', 'Falta opción TipoMovimientoGarantia.TRANSFERENCIA en catálogo', 'registro', NULL);
    END IF;

    UPDATE ven_garantia
    SET monto_transferido = COALESCE(monto_transferido, 0) + v_monto,
        monto_saldo = 0,
        id_estado = v_id_estado_transferida,
        observacion = TRIM(COALESCE(observacion || ' — ', '')
            || 'Transferida al préstamo ' || COALESCE(v_numero_prestamo, p_id_prestamo_destino::TEXT)),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_garantia;

    INSERT INTO ven_garantia_movimiento (
        id_garantia, id_tipo_movimiento, fecha, monto, observacion,
        id_sucursal, id_medio_pago, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_garantia,
        v_id_tipo_transferencia,
        CURRENT_DATE,
        -v_monto,
        'Salida por renovación del préstamo',
        COALESCE(v_id_sucursal, NULL),
        v_garantia.id_medio_pago,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    );

    INSERT INTO ven_garantia (
        id_cliente,
        id_prestamo,
        id_prestamo_detalle,
        id_garantia_origen,
        id_alquiler,
        ubicacion,
        id_producto,
        cantidad_venta,
        id_unidad_medida,
        fecha_registro,
        monto_cobrado,
        monto_devuelto,
        monto_transferido,
        monto_saldo,
        id_estado,
        observacion,
        id_medio_pago,
        id_cuenta_bancaria,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        v_garantia.id_cliente,
        p_id_prestamo_destino,
        p_id_prestamo_detalle,
        p_id_garantia,
        NULL,
        v_garantia.ubicacion,
        v_garantia.id_producto,
        v_garantia.cantidad_venta,
        v_garantia.id_unidad_medida,
        CURRENT_DATE,
        v_monto,
        0,
        0,
        v_monto,
        v_id_estado_activa,
        'Garantía que viene del préstamo anterior (sin nuevo cobro)',
        v_garantia.id_medio_pago,
        v_garantia.id_cuenta_bancaria,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_nueva;

    INSERT INTO ven_garantia_movimiento (
        id_garantia, id_tipo_movimiento, fecha, monto, observacion,
        id_sucursal, id_medio_pago, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        v_id_nueva,
        v_id_tipo_transferencia,
        CURRENT_DATE,
        v_monto,
        'Entrada por renovación del préstamo',
        COALESCE(v_id_sucursal, NULL),
        v_garantia.id_medio_pago,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    );

    RETURN ven_obtener_garantia(v_id_nueva);
END;
$function$;
