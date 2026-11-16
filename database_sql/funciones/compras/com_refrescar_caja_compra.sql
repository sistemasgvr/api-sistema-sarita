-- Recalcula el arqueo de las cajas cerradas que toca un cambio de pago de compra sin efectivo
DROP FUNCTION IF EXISTS public.com_refrescar_caja_compra (
  p_antes jsonb,
  p_despues jsonb,
  p_observacion character varying,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.com_refrescar_caja_compra (
  p_antes jsonb,
  p_despues jsonb,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS void LANGUAGE plpgsql AS $function$
DECLARE
    v_caja RECORD;
BEGIN
    IF p_antes IS NOT DISTINCT FROM p_despues THEN
        RETURN;
    END IF;

    -- Los pagos en efectivo ya pasaron por com_assert_caja_compra (caja abierta): solo quedan los demás.
    FOR v_caja IN
        SELECT DISTINCT (p->>'fecha')::DATE AS fecha, (p->>'idSucursal')::INTEGER AS id_sucursal,
               (p->>'monto')::NUMERIC AS monto
        FROM unnest(ARRAY[p_antes, p_despues]) AS p
        WHERE p IS NOT NULL
          AND p->>'fecha' IS NOT NULL
          AND NOT COALESCE((p->>'esEfectivo')::BOOLEAN, FALSE)
    LOOP
        PERFORM fin_caja_refrescar_cerrada(
            v_caja.fecha, v_caja.id_sucursal, v_caja.monto,
            COALESCE(p_observacion, 'Compra sin efectivo registrada con la caja cerrada'),
            p_id_usuario
        );
    END LOOP;
END;
$function$;
