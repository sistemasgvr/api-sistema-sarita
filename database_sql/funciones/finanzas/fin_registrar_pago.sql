-- Registra un pago/cobranza sobre una cuenta financiera y recalcula su saldo.
-- No crea cuentas: solo aplica pagos a cuentas ya existentes.

DROP FUNCTION IF EXISTS fin_registrar_pago(INT, VARCHAR, DATE, NUMERIC, INT, VARCHAR, VARCHAR, INT);

CREATE OR REPLACE FUNCTION fin_registrar_pago(
    p_id_cuenta     INT,
    p_tipo          VARCHAR,
    p_fecha_pago    DATE    DEFAULT NULL,
    p_monto         NUMERIC DEFAULT NULL,
    p_id_medio_pago INT     DEFAULT NULL,
    p_referencia    VARCHAR DEFAULT NULL,
    p_observacion   VARCHAR DEFAULT NULL,
    p_id_usuario    INT     DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_tipo  INT;
    v_cuenta   fin_cuenta%ROWTYPE;
    v_saldo    NUMERIC;
    v_id_pago  INT;
BEGIN
    SET TIME ZONE 'America/Lima';

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

    v_saldo := COALESCE(v_cuenta.monto_saldo, v_cuenta.monto_pendiente - COALESCE(v_cuenta.monto_abonado, 0));

    IF p_monto IS NULL OR p_monto <= 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El monto debe ser mayor a cero');
    END IF;

    IF p_monto > v_saldo + 0.0001 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El monto excede el saldo pendiente');
    END IF;

    INSERT INTO fin_pago (
        id_cuenta, fecha_pago, monto, id_medio_pago, referencia, observacion, id_usuario_creacion
    ) VALUES (
        p_id_cuenta,
        COALESCE(p_fecha_pago, CURRENT_DATE),
        p_monto,
        p_id_medio_pago,
        NULLIF(TRIM(p_referencia), ''),
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario
    )
    RETURNING id INTO v_id_pago;

    UPDATE fin_cuenta
       SET monto_abonado = COALESCE(monto_abonado, 0) + p_monto,
           monto_saldo   = v_saldo - p_monto,
           id_usuario_modificacion = p_id_usuario,
           fecha_modificacion = NOW()
     WHERE id = p_id_cuenta;

    RETURN json_build_object(
        'registro', json_build_object(
            'id', v_id_pago,
            'idCuenta', p_id_cuenta,
            'monto', p_monto,
            'saldoRestante', v_saldo - p_monto
        )
    );
END;
$$;
