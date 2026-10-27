-- Elimina (lógicamente) usuario
DROP FUNCTION IF EXISTS public.auth_eliminar_usuario (p_id integer);

CREATE OR REPLACE FUNCTION public.auth_eliminar_usuario (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE auth_usuarios
    SET estado = FALSE, fecha_modificacion = NOW()
    WHERE id = p_id AND estado = TRUE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
