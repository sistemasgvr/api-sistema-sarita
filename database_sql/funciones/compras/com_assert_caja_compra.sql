-- Function: com_assert_caja_compra
-- 20261023: valida que un cambio en el pago de caja de una compra
-- (com_pago_caja_compra antes / después) caiga en una caja abierta.
--
-- Devuelve NULL si es válido o el mensaje de error, igual que
-- fin_caja_assert_abierta. Sin cambio no valida nada: editar la glosa de una
-- compra de un día ya cerrado sigue permitido.
--
-- Solo los medios con AFECTA_CAJA (efectivo, Yape, Plin) exigen la caja: son
-- los que entran al arqueo. Una compra pagada por transferencia puede
-- registrarse aunque la factura llegue días después y esa caja esté cerrada.
-- Se valida la caja del pago anterior y la del nuevo: mover una compra en
-- efectivo de una caja cerrada a otra abierta también altera la cerrada.

DROP FUNCTION IF EXISTS com_assert_caja_compra(p_antes jsonb, p_despues jsonb);

CREATE OR REPLACE FUNCTION com_assert_caja_compra(p_antes jsonb, p_despues jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
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
