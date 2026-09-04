-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_actualizar_garantia_manual
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
DROP FUNCTION IF EXISTS ven_actualizar_garantia_manual(p_id integer, p_fecha date, p_id_cliente integer, p_id_medio_pago integer, p_importe numeric, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION ven_actualizar_garantia_manual(p_id integer, p_fecha date DEFAULT NULL::date, p_id_cliente integer DEFAULT NULL::integer, p_id_medio_pago integer DEFAULT NULL::integer, p_importe numeric DEFAULT NULL::numeric, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_cuenta_bancaria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_garantia RECORD;
    v_es_manual BOOLEAN;
    v_monto NUMERIC(12,4);
    v_id_tipo_cobro INTEGER;
    v_medio INTEGER;
    v_cuenta INTEGER;
    v_error TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_garantia
    FROM ven_garantia
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Garantía no encontrada', 'registro', NULL);
    END IF;

    v_es_manual :=
        v_garantia.id_prestamo IS NULL
        AND v_garantia.id_alquiler IS NULL
        AND NOT EXISTS (
            SELECT 1
            FROM ven_garantia_movimiento gm
            WHERE gm.id_garantia = v_garantia.id
              AND gm.estado = 1
              AND gm.id_comprobante IS NOT NULL
        );

    IF NOT v_es_manual THEN
        RETURN json_build_object(
            'error',
            'Solo se pueden editar garantías manuales (sin préstamo, alquiler ni comprobante POS)',
            'registro',
            NULL
        );
    END IF;

    IF COALESCE(v_garantia.monto_devuelto, 0) > 0 OR v_garantia.fecha_reembolso IS NOT NULL THEN
        RETURN json_build_object(
            'error',
            'No se puede editar una garantía con devoluciones registradas',
            'registro',
            NULL
        );
    END IF;

    IF p_id_cliente IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_medio_pago IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_medio_pago AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El método de pago indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_medio := COALESCE(p_id_medio_pago, v_garantia.id_medio_pago);
    -- Cambiar de medio invalida la cuenta anterior.
    v_cuenta := CASE
        WHEN p_id_cuenta_bancaria IS NOT NULL THEN p_id_cuenta_bancaria
        WHEN p_id_medio_pago IS NOT NULL
             AND p_id_medio_pago IS DISTINCT FROM v_garantia.id_medio_pago THEN NULL
        ELSE v_garantia.id_cuenta_bancaria
    END;

    v_error := fin_validar_cuenta_medio_pago(v_medio, v_cuenta);
    IF v_error IS NOT NULL THEN
        RETURN json_build_object('error', v_error, 'registro', NULL);
    END IF;

    IF p_importe IS NOT NULL THEN
        v_monto := ROUND(p_importe::NUMERIC, 4);
        IF v_monto <= 0 THEN
            RETURN json_build_object('error', 'El importe debe ser mayor a cero', 'registro', NULL);
        END IF;
    ELSE
        v_monto := NULL;
    END IF;

    UPDATE ven_garantia
    SET
        fecha_registro = COALESCE(p_fecha, fecha_registro),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_medio_pago = v_medio,
        id_cuenta_bancaria = v_cuenta,
        monto_cobrado = COALESCE(v_monto, monto_cobrado),
        monto_saldo = COALESCE(v_monto, monto_saldo),
        observacion = CASE
            WHEN p_observacion IS NULL THEN observacion
            WHEN TRIM(p_observacion) = '' THEN NULL
            ELSE TRIM(p_observacion)
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    IF v_monto IS NOT NULL THEN
        SELECT lo.id INTO v_id_tipo_cobro
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'COBRO' AND lo.estado = 1
        LIMIT 1;

        UPDATE ven_garantia_movimiento gm
        SET
            monto = v_monto,
            fecha = COALESCE(p_fecha, gm.fecha),
            id_medio_pago = v_medio,
            id_cuenta_bancaria = v_cuenta,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE gm.id_garantia = p_id
          AND gm.estado = 1
          AND gm.id_tipo_movimiento = v_id_tipo_cobro;
    ELSIF p_fecha IS NOT NULL THEN
        SELECT lo.id INTO v_id_tipo_cobro
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'COBRO' AND lo.estado = 1
        LIMIT 1;

        UPDATE ven_garantia_movimiento gm
        SET
            fecha = p_fecha,
            id_medio_pago = v_medio,
            id_cuenta_bancaria = v_cuenta,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE gm.id_garantia = p_id
          AND gm.estado = 1
          AND gm.id_tipo_movimiento = v_id_tipo_cobro;
    END IF;

    RETURN ven_obtener_garantia(p_id);
END;
$function$;
