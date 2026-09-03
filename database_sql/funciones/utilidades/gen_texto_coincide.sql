-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_texto_coincide
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
DROP FUNCTION IF EXISTS gen_texto_coincide(p_haystack text, p_needle text);

CREATE OR REPLACE FUNCTION gen_texto_coincide(p_haystack text, p_needle text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
  SELECT CASE
    WHEN nullif(btrim(coalesce(p_needle, '')), '') IS NULL THEN TRUE
    ELSE gen_normalizar_texto(p_haystack) LIKE '%' || gen_normalizar_texto(p_needle) || '%'
  END;
$function$;
