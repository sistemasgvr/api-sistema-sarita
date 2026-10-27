-- Formatea una cantidad numérica como texto sin ceros decimales sobrantes
DROP FUNCTION IF EXISTS public.gen_formato_cantidad (p_valor numeric);

CREATE OR REPLACE FUNCTION public.gen_formato_cantidad (p_valor numeric) RETURNS text LANGUAGE sql IMMUTABLE AS $function$
    SELECT CASE
        WHEN p_valor IS NULL THEN '0'
        WHEN p_valor = TRUNC(p_valor) THEN TRUNC(p_valor)::TEXT
        ELSE RTRIM(RTRIM(p_valor::TEXT, '0'), '.')
    END;
$function$;
