-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_formato_cantidad
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.962Z
DROP FUNCTION IF EXISTS gen_formato_cantidad(p_valor numeric);

CREATE OR REPLACE FUNCTION gen_formato_cantidad(p_valor numeric)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
    SELECT CASE
        WHEN p_valor IS NULL THEN '0'
        WHEN p_valor = TRUNC(p_valor) THEN TRUNC(p_valor)::TEXT
        ELSE RTRIM(RTRIM(p_valor::TEXT, '0'), '.')
    END;
$function$;
