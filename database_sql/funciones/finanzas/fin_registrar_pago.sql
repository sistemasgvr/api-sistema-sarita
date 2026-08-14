-- Registra un pago/cobranza sobre una cuenta financiera y recalcula su saldo.
-- No crea cuentas: solo aplica pagos a cuentas ya existentes.
-- Los pagos de préstamos con cuotas se aplican a la CUOTA HIJA correspondiente
-- (no a la cabecera del plan).

DROP FUNCTION IF EXISTS fin_registrar_pago(INT, VARCHAR, DATE, NUMERIC, INT, VARCHAR, VARCHAR, INT);
DROP FUNCTION IF EXISTS fin_registrar_pago(INT, VARCHAR, DATE, NUMERIC, INT, INT, VARCHAR, VARCHAR, VARCHAR, INT);

CREATE OR REPLACE FUNCTION fin_registrar_pago(
    p_id_cuenta          INT,
    p_tipo               VARCHAR,
    p_fecha_pago         DATE    DEFAULT NULL,
    p_monto              NUMERIC DEFAULT NULL,
    p_id_medio_pago      INT     DEFAULT NULL,
    p_id_cuenta_bancaria INT     DEFAULT NULL,
    p_numero_operacion   VARCHAR DEFAULT NULL,
    p_referencia         VARCHAR DEFAULT NULL,
    p_observacion        VARCHAR DEFAULT NULL,
    p_id_usuario         INT     DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_tipo     INT;
    v_cuenta      fin_cuenta%ROWTYPE;
    v_saldo       NUMERIC(12,2);
    v_monto       NUMERIC(12,2);
    v_nuevo_saldo NUMERIC(12,2);
    v_id_pago     INT;
    v_err_caja TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_err_caja := fin_caja_assert_abierta(COALESCE(p_fecha_pago, CURRENT_DATE), NULL);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error', v_err_caja);
    END IF;

    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera'
      AND glo.nombre = UPPER(p_tipo)
    LIMIT 1;

    SELECT * INTO v_cuenta FROM fin_cuenta WHERE id = p_id_cuenta AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La cuenta no existe o está inactiva');
    END IF;

    IF v_id_tipo IS NOT NULL AND v_cuenta.id_tipo_cuenta <> v_id_tipo THEN
        RETURN json_build_object('registro', NULL, 'error', 'La cuenta no corresponde al tipo indicado');
    END IF;

    -- No permitir pagar directamente contra la cabecera de un plan de cuotas
    IF v_cuenta.numero_cuotas_total IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error',
            'Esta cuenta es un plan de cuotas: registra el pago sobre la cuota correspondiente');
    END IF;

    v_saldo := fin_redondear_monto(
        COALESCE(v_cuenta.monto_saldo, v_cuenta.monto_pendiente - COALESCE(v_cuenta.monto_abonado, 0))
    );
    v_monto := fin_redondear_monto(p_monto);

    IF v_monto IS NULL OR v_monto <= 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El monto debe ser mayor a cero');
    END IF;

    IF v_monto > v_saldo THEN
        RETURN json_build_object('registro', NULL, 'error', 'El monto excede el saldo pendiente');
    END IF;

    -- La fecha de pago no puede ser anterior a la emisión de la cuenta
    IF COALESCE(p_fecha_pago, CURRENT_DATE) < v_cuenta.fecha_emision THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', format(
                'La fecha del pago (%s) no puede ser anterior a la fecha de emisión de la cuenta (%s)',
                to_char(COALESCE(p_fecha_pago, CURRENT_DATE), 'DD/MM/YYYY'),
                to_char(v_cuenta.fecha_emision, 'DD/MM/YYYY')
            )
        );
    END IF;

    INSERT INTO fin_pago (
        id_cuenta, fecha_pago, monto,
        id_medio_pago, id_cuenta_bancaria, numero_operacion,
        referencia, observacion, id_usuario_creacion
    ) VALUES (
        p_id_cuenta,
        COALESCE(p_fecha_pago, CURRENT_DATE),
        v_monto,
        p_id_medio_pago,
        p_id_cuenta_bancaria,
        NULLIF(TRIM(p_numero_operacion), ''),
        NULLIF(TRIM(p_referencia), ''),
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario
    )
    RETURNING id INTO v_id_pago;

    v_nuevo_saldo := fin_redondear_monto(v_saldo - v_monto);

    IF v_nuevo_saldo <= 0 THEN
        UPDATE fin_cuenta
           SET monto_abonado = fin_redondear_monto(monto_pendiente),
               monto_saldo   = 0,
               id_usuario_modificacion = p_id_usuario,
               fecha_modificacion = NOW()
         WHERE id = p_id_cuenta;
        v_nuevo_saldo := 0;
    ELSE
        UPDATE fin_cuenta
           SET monto_abonado = fin_redondear_monto(COALESCE(monto_abonado, 0) + v_monto),
               monto_saldo   = v_nuevo_saldo,
               id_usuario_modificacion = p_id_usuario,
               fecha_modificacion = NOW()
         WHERE id = p_id_cuenta;
    END IF;

    IF v_cuenta.id_cuenta_padre IS NOT NULL THEN
        PERFORM fin_refrescar_cabecera_plan(v_cuenta.id_cuenta_padre);
    END IF;

    RETURN json_build_object(
        'registro', json_build_object(
            'id', v_id_pago,
            'idCuenta', p_id_cuenta,
            'monto', v_monto,
            'saldoRestante', v_nuevo_saldo
        )
    );
END;
$$;
