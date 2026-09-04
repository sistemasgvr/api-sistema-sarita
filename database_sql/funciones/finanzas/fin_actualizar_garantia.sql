-- Function: fin_actualizar_garantia
-- Fase 3: admite la cuenta bancaria del cobro.

DROP FUNCTION IF EXISTS fin_actualizar_garantia(p_id integer, p_fecha date, p_id_cliente integer, p_id_medio_pago integer, p_importe numeric, p_observacion character varying, p_id_usuario integer);
DROP FUNCTION IF EXISTS fin_actualizar_garantia(p_id integer, p_fecha date, p_id_cliente integer, p_id_medio_pago integer, p_importe numeric, p_observacion character varying, p_id_usuario integer, p_id_cuenta_bancaria integer);

CREATE OR REPLACE FUNCTION fin_actualizar_garantia(
    p_id integer,
    p_fecha date DEFAULT NULL::date,
    p_id_cliente integer DEFAULT NULL::integer,
    p_id_medio_pago integer DEFAULT NULL::integer,
    p_importe numeric DEFAULT NULL::numeric,
    p_observacion character varying DEFAULT NULL::character varying,
    p_id_usuario integer DEFAULT NULL::integer,
    p_id_cuenta_bancaria integer DEFAULT NULL::integer
)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_garantia   fin_garantia%ROWTYPE;
    v_id_cliente INT;
    v_medio      INT;
    v_cuenta     INT;
    v_error      TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_garantia FROM fin_garantia WHERE id = p_id AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La garantía no existe o está inactiva');
    END IF;

    -- No permitir editar datos si ya fue reembolsada
    IF v_garantia.fecha_reembolso IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error',
            'Esta garantía ya fue reembolsada. Anula el reembolso primero para editarla.');
    END IF;

    IF p_id_cliente IS NOT NULL THEN
        SELECT id INTO v_id_cliente FROM cli_clientes WHERE id = p_id_cliente AND estado = 1;
        IF v_id_cliente IS NULL THEN
            RETURN json_build_object('registro', NULL, 'error', 'El cliente no existe o está inactivo');
        END IF;
    END IF;

    IF p_importe IS NOT NULL AND p_importe <= 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El importe debe ser mayor a cero');
    END IF;

    v_medio := COALESCE(p_id_medio_pago, v_garantia.id_medio_pago);
    -- Cambiar de medio invalida la cuenta anterior: si no llega una nueva, se
    -- valida contra NULL y el mensaje pide la que corresponde.
    v_cuenta := CASE
        WHEN p_id_cuenta_bancaria IS NOT NULL THEN p_id_cuenta_bancaria
        WHEN p_id_medio_pago IS NOT NULL
             AND p_id_medio_pago IS DISTINCT FROM v_garantia.id_medio_pago THEN NULL
        ELSE v_garantia.id_cuenta_bancaria
    END;

    v_error := fin_validar_cuenta_medio_pago(v_medio, v_cuenta);
    IF v_error IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error', v_error);
    END IF;

    UPDATE fin_garantia SET
        fecha         = COALESCE(p_fecha, fecha),
        id_cliente    = COALESCE(p_id_cliente, id_cliente),
        id_medio_pago = v_medio,
        id_cuenta_bancaria = v_cuenta,
        importe       = COALESCE(p_importe, importe),
        observacion   = CASE
            WHEN p_observacion IS NULL THEN observacion
            WHEN TRIM(p_observacion) = '' THEN NULL
            ELSE TRIM(p_observacion)
        END,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('registro', fin_garantia_registro(p_id));
END;
$function$;
