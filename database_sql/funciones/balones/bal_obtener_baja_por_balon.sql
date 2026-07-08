CREATE OR REPLACE FUNCTION bal_obtener_baja_por_balon(p_id_balon INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id INTO v_id
    FROM bal_baja_balon
    WHERE id_balon = p_id_balon AND estado = 1
    ORDER BY id DESC
    LIMIT 1;

    IF v_id IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_baja_balon(v_id);
END;
$function$;
