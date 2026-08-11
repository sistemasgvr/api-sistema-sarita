DROP FUNCTION IF EXISTS ven_crear_garantia(INTEGER, NUMERIC, INTEGER, INTEGER, INTEGER, VARCHAR, NUMERIC, INTEGER, DATE, VARCHAR, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS ven_crear_garantia(INTEGER, NUMERIC, INTEGER, INTEGER, INTEGER, VARCHAR, NUMERIC, INTEGER, DATE, VARCHAR, INTEGER, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION ven_crear_garantia(
    p_id_cliente INTEGER,
    p_monto NUMERIC,
    p_id_comprobante INTEGER DEFAULT NULL,
    p_id_prestamo INTEGER DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_ubicacion VARCHAR DEFAULT NULL,
    p_cantidad_venta NUMERIC DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_fecha_registro DATE DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_id_alquiler INTEGER DEFAULT NULL,
    p_id_medio_pago INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado_activa INTEGER;
    v_id_tipo_cobro INTEGER;
    v_monto NUMERIC(12,4);
    v_fecha DATE;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_monto := ROUND(COALESCE(p_monto, 0)::NUMERIC, 4);
    IF v_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto de garantía debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF p_id_prestamo IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_prestamo WHERE id = p_id_prestamo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_alquiler IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_alquiler WHERE id = p_id_alquiler AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El alquiler indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_producto IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_comprobante IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_medio_pago IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_medio_pago AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El método de pago indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado_activa
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGarantia' AND lo.nombre = 'ACTIVA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_activa IS NULL THEN
        RETURN json_build_object('error', 'Falta opción EstadoGarantia.ACTIVA en catálogo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_cobro
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'COBRO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_cobro IS NULL THEN
        RETURN json_build_object('error', 'Falta opción TipoMovimientoGarantia.COBRO en catálogo', 'registro', NULL);
    END IF;

    v_fecha := COALESCE(p_fecha_registro, CURRENT_DATE);

    INSERT INTO ven_garantia (
        id_cliente,
        id_prestamo,
        id_alquiler,
        ubicacion,
        id_producto,
        cantidad_venta,
        id_unidad_medida,
        fecha_registro,
        monto_cobrado,
        monto_devuelto,
        monto_saldo,
        id_estado,
        observacion,
        id_medio_pago,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_cliente,
        p_id_prestamo,
        p_id_alquiler,
        NULLIF(TRIM(COALESCE(p_ubicacion, '')), ''),
        p_id_producto,
        p_cantidad_venta,
        p_id_unidad_medida,
        v_fecha,
        v_monto,
        0,
        v_monto,
        v_id_estado_activa,
        NULLIF(TRIM(COALESCE(p_observacion, '')), ''),
        p_id_medio_pago,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    INSERT INTO ven_garantia_movimiento (
        id_garantia,
        id_tipo_movimiento,
        id_comprobante,
        fecha,
        monto,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        v_id,
        v_id_tipo_cobro,
        p_id_comprobante,
        v_fecha,
        v_monto,
        'Cobro inicial de garantía',
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    );

    RETURN ven_obtener_garantia(v_id);
END;
$function$;
