-- Function: fin_crear_caja_deposito
-- Fase 3: la cuenta bancaria ya existía en la tabla, pero no se validaba que
-- fuera una cuenta de la EMPRESA ni que aceptara el medio de pago elegido.

DROP FUNCTION IF EXISTS fin_crear_caja_deposito(p_fecha date, p_monto numeric, p_id_cuenta_bancaria integer, p_id_medio_pago integer, p_numero_operacion character varying, p_observacion character varying, p_id_sesion integer, p_id_usuario integer, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION fin_crear_caja_deposito(
    p_fecha date,
    p_monto numeric,
    p_id_cuenta_bancaria integer DEFAULT NULL::integer,
    p_id_medio_pago integer DEFAULT NULL::integer,
    p_numero_operacion character varying DEFAULT NULL::character varying,
    p_observacion character varying DEFAULT NULL::character varying,
    p_id_sesion integer DEFAULT NULL::integer,
    p_id_usuario integer DEFAULT NULL::integer,
    p_id_sucursal integer DEFAULT NULL::integer
)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INT;
    v_registro JSON;
    v_sesion_id INT;
    v_sucursal INT;
    v_err_caja TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL OR COALESCE(p_monto, 0) <= 0 THEN
        RETURN json_build_object('error', 'Fecha y monto (> 0) son obligatorios', 'registro', NULL);
    END IF;

    -- Un depósito saca efectivo de la caja y lo mete al banco: la cuenta destino
    -- es obligatoria siempre, aunque el medio no la exigiera por sí solo.
    IF p_id_cuenta_bancaria IS NULL THEN
        RETURN json_build_object(
            'error', 'Indica la cuenta bancaria de la empresa donde se deposita el dinero',
            'registro', NULL
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_cuenta_bancaria
        WHERE id = p_id_cuenta_bancaria AND estado = 1 AND ambito = 'EMPRESA'
    ) THEN
        RETURN json_build_object(
            'error', 'La cuenta de destino debe ser una cuenta bancaria activa de la empresa',
            'registro', NULL
        );
    END IF;

    v_sucursal := p_id_sucursal;
    v_sesion_id := p_id_sesion;

    IF v_sesion_id IS NOT NULL THEN
        SELECT s.id_sucursal INTO v_sucursal
        FROM fin_caja_sesion s
        INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = v_sesion_id AND s.estado = 1 AND UPPER(est.nombre) = 'ABIERTA';

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La sesión de caja indicada no está abierta', 'registro', NULL);
        END IF;
    ELSE
        SELECT s.id, s.id_sucursal INTO v_sesion_id, v_sucursal
        FROM fin_caja_sesion s
        INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.estado = 1 AND s.fecha = p_fecha AND UPPER(est.nombre) = 'ABIERTA'
          AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
        ORDER BY s.id DESC
        LIMIT 1;
    END IF;

    v_err_caja := fin_caja_assert_abierta(p_fecha, v_sucursal);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('error', v_err_caja, 'registro', NULL);
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
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
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
