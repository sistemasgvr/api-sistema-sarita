-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_estado_cuenta_calculado
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.959Z
DROP FUNCTION IF EXISTS fin_estado_cuenta_calculado(p_saldo numeric, p_monto_abonado numeric, p_fecha_vencimiento date);

CREATE OR REPLACE FUNCTION fin_estado_cuenta_calculado(p_saldo numeric, p_monto_abonado numeric, p_fecha_vencimiento date)
 RETURNS character varying
 LANGUAGE sql
 STABLE
AS $function$
    SELECT CASE
        WHEN fin_redondear_monto(p_saldo) <= 0 THEN 'PAGADO'
        WHEN p_fecha_vencimiento IS NOT NULL AND p_fecha_vencimiento < CURRENT_DATE THEN 'VENCIDO'
        WHEN fin_redondear_monto(p_monto_abonado) > 0 THEN 'PARCIAL'
        ELSE 'PENDIENTE'
    END;
$function$;
