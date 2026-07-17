CREATE OR REPLACE FUNCTION gen_listar_provincias(p_id_departamento INTEGER DEFAULT NULL)
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
            pr.id,
            pr.id_departamento,
            d.nombre AS nombre_departamento,
            d.id_pais,
            pr.nombre,
            pr.estado
        FROM gen_provincia pr
        INNER JOIN gen_departamento d ON pr.id_departamento = d.id
        WHERE pr.estado = 1
          AND d.estado = 1
          AND (p_id_departamento IS NULL OR pr.id_departamento = p_id_departamento)
    ) t;

    RETURN v_registros;
END;
$function$;
