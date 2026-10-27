-- Redondea un monto a 2 decimales (NULL como 0)
DROP FUNCTION IF EXISTS public.fin_redondear_monto (p_monto numeric);

CREATE OR REPLACE FUNCTION public.fin_redondear_monto (p_monto numeric) RETURNS numeric LANGUAGE sql IMMUTABLE AS $function$
    SELECT ROUND(COALESCE(p_monto, 0), 2)::NUMERIC(12,2);
$function$;
