-- Function: fin_reembolsar_garantia
-- Fase 3: el reembolso lleva su propia cuenta bancaria. No tiene por qué ser la
-- misma por la que entró: el cliente pudo pagar por Yape y pedir la devolución
-- por transferencia.

DROP FUNCTION IF EXISTS fin_reembolsar_garantia(p_id integer, p_fecha_reembolso date, p_id_medio_reembolso integer, p_observacion_reembolso character varying, p_id_usuario integer);
DROP FUNCTION IF EXISTS fin_reembolsar_garantia(p_id integer, p_fecha_reembolso date, p_id_medio_reembolso integer, p_observacion_reembolso character varying, p_id_usuario integer, p_id_cuenta_bancaria_reembolso integer);

CREATE OR REPLACE FUNCTION fin_reembolsar_garantia(
    p_id integer,
    p_fecha_reembolso date,
    p_id_medio_reembolso integer,
    p_observacion_reembolso character varying DEFAULT NULL::character varying,
    p_id_usuario integer DEFAULT NULL::integer,
    p_id_cuenta_bancaria_reembolso integer DEFAULT NULL::integer
)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_garantia  fin_garantia%ROWTYPE;
    v_id_devuelta INT;
    v_error TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_garantia FROM fin_garantia WHERE id = p_id AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La garantía no existe o está inactiva');
    END IF;

    IF v_garantia.fecha_reembolso IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error',
            'Esta garantía ya fue reembolsada el ' || to_char(v_garantia.fecha_reembolso, 'DD/MM/YYYY'));
    END IF;

    IF p_fecha_reembolso IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'La fecha del reembolso es obligatoria');
    END IF;

    IF p_fecha_reembolso < v_garantia.fecha THEN
        RETURN json_build_object('registro', NULL, 'error',
            format('La fecha del reembolso (%s) no puede ser anterior a la fecha de recepción de la garantía (%s)',
                to_char(p_fecha_reembolso, 'DD/MM/YYYY'),
                to_char(v_garantia.fecha, 'DD/MM/YYYY')));
    END IF;

    v_error := fin_validar_cuenta_medio_pago(p_id_medio_reembolso, p_id_cuenta_bancaria_reembolso);
    IF v_error IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error', v_error);
    END IF;

    SELECT glo.id INTO v_id_devuelta
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'EstadoGarantia' AND glo.nombre = 'DEVUELTA'
    LIMIT 1;

    UPDATE fin_garantia SET
        fecha_reembolso       = p_fecha_reembolso,
        id_medio_reembolso    = p_id_medio_reembolso,
        id_cuenta_bancaria_reembolso = p_id_cuenta_bancaria_reembolso,
        observacion_reembolso = NULLIF(TRIM(p_observacion_reembolso), ''),
        id_usuario_reembolso  = p_id_usuario,
        id_estado             = COALESCE(v_id_devuelta, id_estado),
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion    = NOW()
    WHERE id = p_id;

    RETURN json_build_object('registro', fin_garantia_registro(p_id));
END;
$function$;
