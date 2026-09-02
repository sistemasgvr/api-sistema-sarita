-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_listar_paises
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.736Z
DROP FUNCTION IF EXISTS gen_listar_paises();

CREATE OR REPLACE FUNCTION gen_listar_paises()
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.nombre ASC), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            p.id,
            p.nombre,
            p.estado
        FROM gen_pais p
        WHERE p.estado = 1
    ) t;

    RETURN v_registros;
END;
$function$
