-- Lista los departamentos activos, opcionalmente de un país
DROP FUNCTION IF EXISTS public.gen_listar_departamentos (p_id_pais integer);

CREATE OR REPLACE FUNCTION public.gen_listar_departamentos (p_id_pais integer DEFAULT NULL::integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.nombre ASC), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            d.id,
            d.id_pais,
            p.nombre AS nombre_pais,
            d.nombre,
            d.estado
        FROM gen_departamento d
        INNER JOIN gen_pais p ON d.id_pais = p.id
        WHERE d.estado = 1
          AND p.estado = 1
          AND (p_id_pais IS NULL OR d.id_pais = p_id_pais)
    ) t;

    RETURN v_registros;
END;
$function$;
