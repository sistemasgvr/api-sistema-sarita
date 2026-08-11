DROP FUNCTION IF EXISTS ven_devolver_garantia(INTEGER, NUMERIC, INTEGER, DATE, VARCHAR, INTEGER);
DROP FUNCTION IF EXISTS ven_devolver_garantia(INTEGER, NUMERIC, INTEGER, DATE, VARCHAR, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION ven_devolver_garantia(
    p_id INTEGER,
    p_monto NUMERIC,
    p_id_comprobante INTEGER DEFAULT NULL,
    p_fecha DATE DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_id_medio_reembolso INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_garantia RECORD;
    v_monto NUMERIC(12,4);
    v_nuevo_devuelto NUMERIC(12,4);
    v_nuevo_saldo NUMERIC(12,4);
    v_id_tipo_devolucion INTEGER;
    v_id_estado INTEGER;
    v_nombre_estado VARCHAR;
    v_fecha DATE;
    v_obs VARCHAR(500);
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id IS NULL THEN
        RETURN json_build_object('error', 'El id de garantía es obligatorio', 'registro', NULL);
    END IF;

    SELECT * INTO v_garantia
    FROM ven_garantia
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Garantía no encontrada', 'registro', NULL);
    END IF;

    IF COALESCE(v_garantia.monto_saldo, 0) <= 0 THEN
        RETURN json_build_object('error', 'La garantía no tiene saldo pendiente', 'registro', NULL);
    END IF;

    v_monto := ROUND(COALESCE(p_monto, 0)::NUMERIC, 4);
    IF v_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto a devolver debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF v_monto > v_garantia.monto_saldo THEN
        RETURN json_build_object(
            'error',
            'El monto a devolver (' || v_monto || ') supera el saldo (' || v_garantia.monto_saldo || ')',
            'registro',
            NULL
        );
    END IF;

    IF p_id_comprobante IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_medio_reembolso IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_medio_reembolso AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El método de reembolso indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_devolucion
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'DEVOLUCION' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_devolucion IS NULL THEN
        RETURN json_build_object('error', 'Falta opción TipoMovimientoGarantia.DEVOLUCION en catálogo', 'registro', NULL);
    END IF;

    v_nuevo_devuelto := ROUND(COALESCE(v_garantia.monto_devuelto, 0) + v_monto, 4);
    v_nuevo_saldo := ROUND(COALESCE(v_garantia.monto_cobrado, 0) - v_nuevo_devuelto, 4);
    IF v_nuevo_saldo < 0 THEN
        v_nuevo_saldo := 0;
    END IF;

    IF v_nuevo_saldo = 0 THEN
        v_nombre_estado := 'DEVUELTA';
    ELSE
        v_nombre_estado := 'PARCIAL';
    END IF;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGarantia' AND lo.nombre = v_nombre_estado AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object(
            'error',
            'Falta opción EstadoGarantia.' || v_nombre_estado || ' en catálogo',
            'registro',
            NULL
        );
    END IF;

    v_fecha := COALESCE(p_fecha, CURRENT_DATE);
    v_obs := NULLIF(TRIM(COALESCE(p_observacion, '')), '');

    UPDATE ven_garantia
    SET
        monto_devuelto = v_nuevo_devuelto,
        monto_saldo = v_nuevo_saldo,
        id_estado = v_id_estado,
        observacion = COALESCE(v_obs, observacion),
        fecha_reembolso = CASE WHEN v_nuevo_saldo = 0 THEN v_fecha ELSE fecha_reembolso END,
        id_medio_reembolso = COALESCE(p_id_medio_reembolso, id_medio_reembolso),
        observacion_reembolso = COALESCE(v_obs, observacion_reembolso),
        id_usuario_reembolso = CASE
            WHEN v_nuevo_saldo = 0 OR p_id_medio_reembolso IS NOT NULL
                THEN COALESCE(p_id_usuario_auditoria, id_usuario_reembolso)
            ELSE id_usuario_reembolso
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

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
        p_id,
        v_id_tipo_devolucion,
        p_id_comprobante,
        v_fecha,
        v_monto,
        COALESCE(v_obs, 'Devolución de garantía'),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    );

    RETURN ven_obtener_garantia(p_id);
END;
$function$;
