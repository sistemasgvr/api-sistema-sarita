CREATE OR REPLACE FUNCTION gen_normalizar_texto(p_texto TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT lower(
    translate(
      coalesce(p_texto, ''),
      'ÁÀÄÂáàäâÉÈËÊéèëêÍÌÏÎíìïîÓÒÖÔóòöôÚÙÜÛúùüûÝýÑñÇç',
      'AAAAaaaaEEEEeeeeIIIIiiiiOOOOooooUUUUuuuuYyNnCc'
    )
  );
$$;

CREATE OR REPLACE FUNCTION gen_texto_coincide(p_haystack TEXT, p_needle TEXT)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT CASE
    WHEN nullif(btrim(coalesce(p_needle, '')), '') IS NULL THEN TRUE
    ELSE gen_normalizar_texto(p_haystack) LIKE '%' || gen_normalizar_texto(p_needle) || '%'
  END;
$$;
