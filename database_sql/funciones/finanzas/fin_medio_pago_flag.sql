-- Function: fin_medio_pago_flag
-- Fase 3 — fuente única del comportamiento de un medio de pago.
--
-- Mismo criterio que inv_signo_tipo_movimiento (F1): el comportamiento se lee de
-- fin_medio_pago_config, no se infiere del nombre del catálogo. Un medio sin
-- configurar es un error explícito, no un "no afecta caja" silencioso que
-- descuadraría el arqueo sin que nadie se entere.

DROP FUNCTION IF EXISTS fin_medio_pago_flag(p_id_medio_pago integer, p_flag text);

CREATE OR REPLACE FUNCTION fin_medio_pago_flag(p_id_medio_pago integer, p_flag text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v RECORD;
    v_nombre VARCHAR;
BEGIN
    IF p_id_medio_pago IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT c.es_efectivo, c.afecta_caja, c.requiere_cuenta_bancaria,
           c.requiere_numero_operacion, c.es_credito
    INTO v
    FROM fin_medio_pago_config c
    WHERE c.id_medio_pago = p_id_medio_pago AND c.estado = 1;

    IF NOT FOUND THEN
        SELECT nombre INTO v_nombre FROM gen_lista_opciones WHERE id = p_id_medio_pago;
        RAISE EXCEPTION
            'El medio de pago % (id %) no está configurado en fin_medio_pago_config. Configúralo antes de usarlo: define si es efectivo, si afecta caja y si exige cuenta bancaria.',
            COALESCE(v_nombre, '?'), p_id_medio_pago
            USING ERRCODE = '22023';
    END IF;

    RETURN CASE UPPER(p_flag)
        WHEN 'ES_EFECTIVO'               THEN v.es_efectivo
        WHEN 'AFECTA_CAJA'               THEN v.afecta_caja
        WHEN 'REQUIERE_CUENTA_BANCARIA'  THEN v.requiere_cuenta_bancaria
        WHEN 'REQUIERE_NUMERO_OPERACION' THEN v.requiere_numero_operacion
        WHEN 'ES_CREDITO'                THEN v.es_credito
        ELSE NULL
    END;
END;
$function$;
