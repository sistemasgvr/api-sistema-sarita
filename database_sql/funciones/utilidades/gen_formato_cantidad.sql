-- Formatea una cantidad para mensajes al usuario, sin ceros de relleno.
--   14.2857 -> '14.2857'
--   10.0000 -> '10'
--    0.6820 -> '0.682'
--
-- Reemplaza el patrón TO_CHAR(x, 'FM999999990.####'), que estaba en uso pero es
-- inválido en PostgreSQL: '#' no es un carácter de formato numérico, así que
-- TO_CHAR descartaba TODOS los decimales (14.2857 salía como '14') y los mensajes
-- de stock insuficiente y de conversión mentían.
DROP FUNCTION IF EXISTS gen_formato_cantidad(numeric);

CREATE OR REPLACE FUNCTION gen_formato_cantidad(p_valor NUMERIC)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $function$
    SELECT CASE
        WHEN p_valor IS NULL THEN '0'
        WHEN p_valor = TRUNC(p_valor) THEN TRUNC(p_valor)::TEXT
        ELSE RTRIM(RTRIM(p_valor::TEXT, '0'), '.')
    END;
$function$;
