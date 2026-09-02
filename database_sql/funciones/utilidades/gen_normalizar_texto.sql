-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_normalizar_texto
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.741Z
DROP FUNCTION IF EXISTS gen_normalizar_texto(p_texto text);

CREATE OR REPLACE FUNCTION gen_normalizar_texto(p_texto text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
  SELECT lower(
    translate(
      coalesce(p_texto, ''),
      'ÁÀÄÂáàäâÉÈËÊéèëêÍÌÏÎíìïîÓÒÖÔóòöôÚÙÜÛúùüûÝýÑñÇç',
      'AAAAaaaaEEEEeeeeIIIIiiiiOOOOooooUUUUuuuuYyNnCc'
    )
  );
$function$
