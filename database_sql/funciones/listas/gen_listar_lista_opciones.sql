-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_listar_lista_opciones
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.962Z
DROP FUNCTION IF EXISTS gen_listar_lista_opciones(p_id_lista integer);

CREATE OR REPLACE FUNCTION gen_listar_lista_opciones(p_id_lista integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_lista IS NULL THEN
        RETURN '[]'::JSON;
    END IF;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.nombre ASC), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            lo.id,
            lo.id_lista,
            l.nombre AS nombre_lista,
            lo.nombre,
            lo.descripcion,
            lo.estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE lo.estado = 1
          AND l.estado = 1
          AND lo.id_lista = p_id_lista
    ) t;

    RETURN v_registros;
END;
$function$;
