CREATE OR REPLACE FUNCTION gen_contar_notificaciones_no_leidas(
    p_id_usuario INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_total INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario IS NULL THEN
        RETURN json_build_object('total', 0);
    END IF;

    SELECT COUNT(*)::INTEGER
    INTO v_total
    FROM gen_notificacion
    WHERE id_usuario = p_id_usuario
      AND estado = 1
      AND leida = FALSE;

    RETURN json_build_object('total', COALESCE(v_total, 0));
END;
$function$;
