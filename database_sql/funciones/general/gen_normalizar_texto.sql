-- Pasa un texto a minúsculas y quita tildes
DROP FUNCTION IF EXISTS public.gen_normalizar_texto (p_texto text);

CREATE OR REPLACE FUNCTION public.gen_normalizar_texto (p_texto text) RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $function$
  SELECT lower(
    translate(
      coalesce(p_texto, ''),
      'ÁÀÄÂáàäâÉÈËÊéèëêÍÌÏÎíìïîÓÒÖÔóòöôÚÙÜÛúùüûÝýÑñÇç',
      'AAAAaaaaEEEEeeeeIIIIiiiiOOOOooooUUUUuuuuYyNnCc'
    )
  );
$function$;
