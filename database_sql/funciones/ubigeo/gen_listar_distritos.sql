-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_listar_distritos
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.730Z
DROP FUNCTION IF EXISTS gen_listar_distritos(p_id_provincia integer);

CREATE OR REPLACE FUNCTION gen_listar_distritos(p_id_provincia integer DEFAULT NULL::integer)
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
            di.id,
            di.id_provincia,
            pr.nombre AS nombre_provincia,
            pr.id_departamento,
            di.nombre,
            di.codigo_ubigeo,
            di.estado
        FROM gen_distrito di
        INNER JOIN gen_provincia pr ON di.id_provincia = pr.id
        WHERE di.estado = 1
          AND pr.estado = 1
          AND (p_id_provincia IS NULL OR di.id_provincia = p_id_provincia)
    ) t;

    RETURN v_registros;
END;
$function$
