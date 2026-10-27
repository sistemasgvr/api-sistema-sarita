-- Lista los países activos
DROP FUNCTION IF EXISTS public.gen_listar_paises ();

CREATE OR REPLACE FUNCTION public.gen_listar_paises () RETURNS json LANGUAGE plpgsql AS $function$
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
