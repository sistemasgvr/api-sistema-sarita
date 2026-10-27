-- Valida que el cambio de pago de una compra caiga en una caja abierta
DROP FUNCTION IF EXISTS public.com_assert_caja_compra (p_antes jsonb, p_despues jsonb);

CREATE OR REPLACE FUNCTION public.com_assert_caja_compra (p_antes jsonb, p_despues jsonb) RETURNS text LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_pago JSONB;
    v_err TEXT;
BEGIN
    IF p_antes IS NOT DISTINCT FROM p_despues THEN
        RETURN NULL;
    END IF;

    FOREACH v_pago IN ARRAY ARRAY[p_antes, p_despues]
    LOOP
        CONTINUE WHEN v_pago IS NULL OR NOT COALESCE((v_pago->>'afectaCaja')::BOOLEAN, FALSE);

        IF v_pago->>'idSucursal' IS NULL THEN
            RETURN 'Una compra al contado pagada con un medio que afecta caja necesita sucursal: el pago sale de la caja de esa sucursal.';
        END IF;

        v_err := fin_caja_assert_abierta((v_pago->>'fecha')::DATE, (v_pago->>'idSucursal')::INTEGER);
        IF v_err IS NOT NULL THEN
            RETURN 'El pago de esta compra sale de la caja del ' || to_char((v_pago->>'fecha')::DATE, 'DD/MM/YYYY') || '. ' || v_err;
        END IF;
    END LOOP;

    RETURN NULL;
END;
$function$;
