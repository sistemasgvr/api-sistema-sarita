-- Function: ven_crear_garantia
-- Fase 3 (apunte 1.c.vi): la garantía de venta se liga a la cuenta bancaria de
-- la empresa cuando el medio de pago no es efectivo. La cuenta se guarda tanto
-- en la garantía como en su movimiento de COBRO, que es la fila que leen los
-- resúmenes de caja.
DROP FUNCTION IF EXISTS ven_crear_garantia(p_id_cliente integer, p_monto numeric, p_id_comprobante integer, p_id_prestamo integer, p_id_producto integer, p_ubicacion character varying, p_cantidad_venta numeric, p_id_unidad_medida integer, p_fecha_registro date, p_observacion character varying, p_id_usuario_auditoria integer, p_id_alquiler integer, p_id_medio_pago integer);
DROP FUNCTION IF EXISTS ven_crear_garantia(p_id_cliente integer, p_monto numeric, p_id_comprobante integer, p_id_prestamo integer, p_id_producto integer, p_ubicacion character varying, p_cantidad_venta numeric, p_id_unidad_medida integer, p_fecha_registro date, p_observacion character varying, p_id_usuario_auditoria integer, p_id_alquiler integer, p_id_medio_pago integer, p_id_cuenta_bancaria integer, p_numero_operacion character varying);

CREATE OR REPLACE FUNCTION ven_crear_garantia(p_id_cliente integer, p_monto numeric, p_id_comprobante integer DEFAULT NULL::integer, p_id_prestamo integer DEFAULT NULL::integer, p_id_producto integer DEFAULT NULL::integer, p_ubicacion character varying DEFAULT NULL::character varying, p_cantidad_venta numeric DEFAULT NULL::numeric, p_id_unidad_medida integer DEFAULT NULL::integer, p_fecha_registro date DEFAULT NULL::date, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_alquiler integer DEFAULT NULL::integer, p_id_medio_pago integer DEFAULT NULL::integer, p_id_cuenta_bancaria integer DEFAULT NULL::integer, p_numero_operacion character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado_activa INTEGER;
    v_id_tipo_cobro INTEGER;
    v_monto NUMERIC(12,4);
    v_fecha DATE;
    v_id_sucursal INTEGER;
    v_err_caja TEXT;
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

    v_err_caja := fin_validar_cuenta_medio_pago(p_id_medio_pago, p_id_cuenta_bancaria);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('error', v_err_caja, 'registro', NULL);
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

    IF p_id_comprobante IS NOT NULL THEN
        SELECT c.id_sucursal INTO v_id_sucursal
        FROM ven_comprobante c
        WHERE c.id = p_id_comprobante AND c.estado = 1;
    END IF;

    IF v_id_sucursal IS NULL AND p_id_prestamo IS NOT NULL THEN
        SELECT a.id_sucursal INTO v_id_sucursal
        FROM bal_prestamo p
        INNER JOIN gen_almacen a ON a.id = p.id_almacen
        WHERE p.id = p_id_prestamo AND p.estado = 1;
    END IF;

    IF v_id_sucursal IS NULL AND p_id_alquiler IS NOT NULL THEN
        SELECT a.id_sucursal INTO v_id_sucursal
        FROM bal_alquiler al
        INNER JOIN gen_almacen a ON a.id = al.id_almacen
        WHERE al.id = p_id_alquiler AND al.estado = 1;
    END IF;

    v_err_caja := fin_caja_assert_abierta(v_fecha, v_id_sucursal);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('error', v_err_caja, 'registro', NULL);
    END IF;

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
        id_cuenta_bancaria,
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
        p_id_cuenta_bancaria,
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
        id_sucursal,
        id_medio_pago,
        id_cuenta_bancaria,
        numero_operacion,
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
        v_id_sucursal,
        p_id_medio_pago,
        p_id_cuenta_bancaria,
        NULLIF(TRIM(COALESCE(p_numero_operacion, '')), ''),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    );

    RETURN ven_obtener_garantia(v_id);
END;
$function$;
