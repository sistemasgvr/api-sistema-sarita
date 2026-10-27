-- Calcula el estado de una cuenta: PAGADO, VENCIDO, PARCIAL o PENDIENTE
DROP FUNCTION IF EXISTS public.fin_estado_cuenta_calculado (
  p_saldo numeric,
  p_monto_abonado numeric,
  p_fecha_vencimiento date
);

CREATE OR REPLACE FUNCTION public.fin_estado_cuenta_calculado (
  p_saldo numeric,
  p_monto_abonado numeric,
  p_fecha_vencimiento date
) RETURNS character varying LANGUAGE sql STABLE AS $function$
    SELECT CASE
        WHEN fin_redondear_monto(p_saldo) <= 0 THEN 'PAGADO'
        WHEN p_fecha_vencimiento IS NOT NULL AND p_fecha_vencimiento < CURRENT_DATE THEN 'VENCIDO'
        WHEN fin_redondear_monto(p_monto_abonado) > 0 THEN 'PARCIAL'
        ELSE 'PENDIENTE'
    END;
$function$;
