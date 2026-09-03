-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_redondear_monto
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.959Z
DROP FUNCTION IF EXISTS fin_redondear_monto(p_monto numeric);

CREATE OR REPLACE FUNCTION fin_redondear_monto(p_monto numeric)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
AS $function$
    SELECT ROUND(COALESCE(p_monto, 0), 2)::NUMERIC(12,2);
$function$;
