CREATE OR REPLACE FUNCTION gen_listar_paises()
RETURNS JSON
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
$function$;
