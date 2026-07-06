CREATE OR REPLACE FUNCTION auth_activar_usuario(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE auth_usuarios
    SET estado = TRUE, fecha_modificacion = NOW()
    WHERE id = p_id AND estado = FALSE;

    IF NOT FOUND THEN
        RETURN json_build_object('activado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('activado', TRUE, 'id', p_id);
END;
$function$;
