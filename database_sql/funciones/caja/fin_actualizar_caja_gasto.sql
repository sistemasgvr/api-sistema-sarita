-- Function: fin_actualizar_caja_gasto
-- Faltaba: caja.model.ts la llamaba desde PATCH /caja/gastos/:id pero nunca se
-- creó, así que el endpoint fallaba con "function does not exist". Creada en
-- Fase 3 al añadir la cuenta bancaria al gasto.
--
-- Solo se puede editar mientras la caja de esa fecha siga abierta: un gasto de
-- una sesión ya arqueada cambiaría el monto esperado del cierre a posteriori.

DROP FUNCTION IF EXISTS fin_actualizar_caja_gasto(p_id integer, p_concepto character varying, p_monto numeric, p_id_medio_pago integer, p_id_categoria_gasto integer, p_numero_operacion character varying, p_observacion character varying, p_id_usuario integer);
DROP FUNCTION IF EXISTS fin_actualizar_caja_gasto(p_id integer, p_concepto character varying, p_monto numeric, p_id_medio_pago integer, p_id_categoria_gasto integer, p_numero_operacion character varying, p_observacion character varying, p_id_usuario integer, p_id_cuenta_bancaria integer);

CREATE OR REPLACE FUNCTION fin_actualizar_caja_gasto(
    p_id integer,
    p_concepto character varying DEFAULT NULL::character varying,
    p_monto numeric DEFAULT NULL::numeric,
    p_id_medio_pago integer DEFAULT NULL::integer,
    p_id_categoria_gasto integer DEFAULT NULL::integer,
    p_numero_operacion character varying DEFAULT NULL::character varying,
    p_observacion character varying DEFAULT NULL::character varying,
    p_id_usuario integer DEFAULT NULL::integer,
    p_id_cuenta_bancaria integer DEFAULT NULL::integer
)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_actual RECORD;
    v_medio INT;
    v_cuenta INT;
    v_error TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT g.*, s.id_sucursal
    INTO v_actual
    FROM fin_caja_gasto g
    LEFT JOIN fin_caja_sesion s ON s.id = g.id_sesion
    WHERE g.id = p_id AND g.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Gasto de caja no encontrado', 'registro', NULL);
    END IF;

    IF p_monto IS NOT NULL AND p_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto debe ser mayor que cero', 'registro', NULL);
    END IF;

    v_error := fin_caja_assert_abierta(v_actual.fecha, v_actual.id_sucursal);
    IF v_error IS NOT NULL THEN
        RETURN json_build_object('error', v_error, 'registro', NULL);
    END IF;

    v_medio := COALESCE(p_id_medio_pago, v_actual.id_medio_pago);
    -- Al cambiar de medio, la cuenta anterior deja de ser válida: si el llamador
    -- no manda una nueva, se valida contra NULL y el error lo dice.
    v_cuenta := CASE
        WHEN p_id_cuenta_bancaria IS NOT NULL THEN p_id_cuenta_bancaria
        WHEN p_id_medio_pago IS NOT NULL AND p_id_medio_pago IS DISTINCT FROM v_actual.id_medio_pago THEN NULL
        ELSE v_actual.id_cuenta_bancaria
    END;

    v_error := fin_validar_cuenta_medio_pago(v_medio, v_cuenta);
    IF v_error IS NOT NULL THEN
        RETURN json_build_object('error', v_error, 'registro', NULL);
    END IF;

    UPDATE fin_caja_gasto
    SET concepto = COALESCE(NULLIF(TRIM(p_concepto), ''), concepto),
        monto = COALESCE(p_monto, monto),
        id_medio_pago = v_medio,
        id_cuenta_bancaria = v_cuenta,
        id_categoria_gasto = COALESCE(p_id_categoria_gasto, id_categoria_gasto),
        numero_operacion = COALESCE(NULLIF(TRIM(p_numero_operacion), ''), numero_operacion),
        observacion = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion),
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN fin_obtener_caja_gasto(p_id);
END;
$function$;
