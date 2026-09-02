-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_obtener_archivo_por_ruta
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.743Z
DROP FUNCTION IF EXISTS gen_obtener_archivo_por_ruta(p_bucket character varying, p_ruta character varying);

CREATE OR REPLACE FUNCTION gen_obtener_archivo_por_ruta(p_bucket character varying, p_ruta character varying)
 RETURNS json
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
$function$
