-- Function: fin_crear_garantia
-- Fase 3 (apunte 1.c.vi): una garantía cobrada por Yape, transferencia o
-- tarjeta queda ligada a la cuenta bancaria de la empresa que recibió el dinero.

DROP FUNCTION IF EXISTS fin_crear_garantia(p_fecha date, p_id_cliente integer, p_id_medio_pago integer, p_importe numeric, p_observacion character varying, p_id_usuario integer);
DROP FUNCTION IF EXISTS fin_crear_garantia(p_fecha date, p_id_cliente integer, p_id_medio_pago integer, p_importe numeric, p_observacion character varying, p_id_usuario integer, p_id_cuenta_bancaria integer);

CREATE OR REPLACE FUNCTION fin_crear_garantia(
    p_fecha date,
    p_id_cliente integer,
    p_id_medio_pago integer,
    p_importe numeric,
    p_observacion character varying DEFAULT NULL::character varying,
    p_id_usuario integer DEFAULT NULL::integer,
    p_id_cuenta_bancaria integer DEFAULT NULL::integer
)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INT;
    v_id_estado  INT;
    v_id_garantia INT;
    v_error TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'La fecha es obligatoria');
    END IF;
    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente es obligatorio');
    END IF;

    SELECT id INTO v_id_cliente FROM cli_clientes WHERE id = p_id_cliente AND estado = 1;
    IF v_id_cliente IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente no existe o está inactivo');
    END IF;

    IF p_importe IS NULL OR p_importe <= 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El importe debe ser mayor a cero');
    END IF;

    v_error := fin_validar_cuenta_medio_pago(p_id_medio_pago, p_id_cuenta_bancaria);
    IF v_error IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error', v_error);
    END IF;

    SELECT glo.id INTO v_id_estado
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'EstadoGarantia' AND glo.nombre = 'ACTIVA'
    LIMIT 1;

    INSERT INTO fin_garantia (
        fecha, id_cliente, id_medio_pago, id_cuenta_bancaria, importe, observacion,
        id_estado, id_usuario_creacion
    ) VALUES (
        p_fecha, v_id_cliente, p_id_medio_pago, p_id_cuenta_bancaria, p_importe,
        NULLIF(TRIM(p_observacion), ''),
        v_id_estado, p_id_usuario
    ) RETURNING id INTO v_id_garantia;

    RETURN json_build_object('registro', fin_garantia_registro(v_id_garantia));
END;
$function$;
