-- Indica si todas las palabras buscadas aparecen en el texto, sin tildes
DROP FUNCTION IF EXISTS public.gen_texto_coincide (p_haystack text, p_needle text);

CREATE OR REPLACE FUNCTION public.gen_texto_coincide (p_haystack text, p_needle text) RETURNS boolean LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $function$
  SELECT NOT EXISTS (
    SELECT 1
    FROM regexp_split_to_table(btrim(gen_normalizar_texto(p_needle)), '\s+') AS t(palabra)
    WHERE t.palabra <> ''
      AND strpos(gen_normalizar_texto(p_haystack), t.palabra) = 0
  );
$function$;
