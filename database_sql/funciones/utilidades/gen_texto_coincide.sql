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
  -- Cada palabra buscada debe aparecer, en cualquier orden.
  SELECT NOT EXISTS (
    SELECT 1
    FROM regexp_split_to_table(btrim(gen_normalizar_texto(p_needle)), '\s+') AS t(palabra)
    WHERE t.palabra <> ''
      AND strpos(gen_normalizar_texto(p_haystack), t.palabra) = 0
  );
$function$;
