CREATE OR REPLACE FUNCTION gen_obtener_archivo_por_ruta(
    p_bucket VARCHAR,
    p_ruta VARCHAR
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id INTO v_id
    FROM gen_archivo a
    WHERE a.bucket = p_bucket
      AND a.ruta = p_ruta
      AND a.estado = 1
    LIMIT 1;

    IF v_id IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_archivo(v_id);
END;
$function$;
