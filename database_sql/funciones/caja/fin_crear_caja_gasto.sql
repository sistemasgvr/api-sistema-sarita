-- Function: fin_crear_caja_gasto
-- Fase 3: el gasto de caja pagado por un medio no-efectivo queda vinculado a la
-- cuenta bancaria de la empresa de la que salió el dinero (apunte 1.a.i).

DROP FUNCTION IF EXISTS fin_crear_caja_gasto(p_fecha date, p_concepto character varying, p_monto numeric, p_id_medio_pago integer, p_id_categoria_gasto integer, p_numero_operacion character varying, p_observacion character varying, p_id_sesion integer, p_id_usuario integer, p_id_sucursal integer);
DROP FUNCTION IF EXISTS fin_crear_caja_gasto(p_fecha date, p_concepto character varying, p_monto numeric, p_id_medio_pago integer, p_id_categoria_gasto integer, p_numero_operacion character varying, p_observacion character varying, p_id_sesion integer, p_id_usuario integer, p_id_sucursal integer, p_id_cuenta_bancaria integer);

CREATE OR REPLACE FUNCTION fin_crear_caja_gasto(
    p_fecha date,
    p_concepto character varying,
    p_monto numeric,
    p_id_medio_pago integer DEFAULT NULL::integer,
    p_id_categoria_gasto integer DEFAULT NULL::integer,
    p_numero_operacion character varying DEFAULT NULL::character varying,
    p_observacion character varying DEFAULT NULL::character varying,
    p_id_sesion integer DEFAULT NULL::integer,
    p_id_usuario integer DEFAULT NULL::integer,
    p_id_sucursal integer DEFAULT NULL::integer,
    p_id_cuenta_bancaria integer DEFAULT NULL::integer
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

    IF p_fecha IS NULL OR NULLIF(TRIM(p_concepto), '') IS NULL OR COALESCE(p_monto, 0) <= 0 THEN
        RETURN json_build_object('error', 'Fecha, concepto y monto (> 0) son obligatorios', 'registro', NULL);
    END IF;

    v_err_caja := fin_validar_cuenta_medio_pago(p_id_medio_pago, p_id_cuenta_bancaria);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('error', v_err_caja, 'registro', NULL);
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

    INSERT INTO fin_caja_gasto (
        id_sesion, fecha, concepto, monto, id_medio_pago, id_categoria_gasto,
        numero_operacion, observacion, id_cuenta_bancaria, id_usuario_creacion
    ) VALUES (
        v_sesion_id, p_fecha, TRIM(p_concepto), p_monto, p_id_medio_pago, p_id_categoria_gasto,
        NULLIF(TRIM(p_numero_operacion), ''), NULLIF(TRIM(p_observacion), ''),
        p_id_cuenta_bancaria, p_id_usuario
    )
    RETURNING id INTO v_id;

    v_registro := (fin_obtener_caja_gasto(v_id)) -> 'registro';

    RETURN json_build_object('registro', v_registro);
END;
$function$;
