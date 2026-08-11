CREATE OR REPLACE FUNCTION fin_crear_caja_deposito(
    p_fecha DATE,
    p_monto NUMERIC,
    p_id_cuenta_bancaria INT DEFAULT NULL,
    p_id_medio_pago INT DEFAULT NULL,
    p_numero_operacion VARCHAR DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_sesion INT DEFAULT NULL,
    p_id_usuario INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INT;
    v_registro JSON;
    v_sesion_id INT;
    v_err_caja TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL OR COALESCE(p_monto, 0) <= 0 THEN
        RETURN json_build_object('error', 'Fecha y monto (> 0) son obligatorios', 'registro', NULL);
    END IF;

    v_err_caja := fin_caja_assert_abierta(p_fecha, NULL);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('error', v_err_caja, 'registro', NULL);
    END IF;

    v_sesion_id := p_id_sesion;
    IF v_sesion_id IS NULL THEN
        SELECT s.id INTO v_sesion_id
        FROM fin_caja_sesion s
        INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.estado = 1 AND s.fecha = p_fecha AND UPPER(est.nombre) = 'ABIERTA'
        ORDER BY s.id DESC LIMIT 1;
    ELSIF NOT EXISTS (
        SELECT 1
        FROM fin_caja_sesion s
        INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = v_sesion_id AND s.estado = 1 AND UPPER(est.nombre) = 'ABIERTA'
    ) THEN
        RETURN json_build_object('error', 'La sesión de caja indicada no está abierta', 'registro', NULL);
    END IF;

    INSERT INTO fin_caja_deposito (
        id_sesion, fecha, monto, id_cuenta_bancaria, id_medio_pago,
        numero_operacion, observacion, id_usuario_creacion
    ) VALUES (
        v_sesion_id, p_fecha, p_monto, p_id_cuenta_bancaria, p_id_medio_pago,
        NULLIF(TRIM(p_numero_operacion), ''), NULLIF(TRIM(p_observacion), ''), p_id_usuario
    )
    RETURNING id INTO v_id;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            d.id, d.fecha, d.monto,
            d.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            d.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            d.numero_operacion AS "numeroOperacion",
            d.observacion,
            d.id_sesion AS "idSesion"
        FROM fin_caja_deposito d
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = d.id_cuenta_bancaria
        LEFT JOIN gen_lista_opciones mp ON mp.id = d.id_medio_pago
        WHERE d.id = v_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
