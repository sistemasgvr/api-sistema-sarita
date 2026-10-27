-- Elimina (lógicamente) garantia
DROP FUNCTION IF EXISTS public.fin_eliminar_garantia (p_id integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION public.fin_eliminar_garantia (
  p_id integer,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE fin_garantia
       SET estado = 0,
           id_usuario_modificacion = p_id_usuario,
           fecha_modificacion = NOW()
     WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', false, 'id', p_id, 'error', 'La garantía no existe o ya está inactiva');
    END IF;

    RETURN json_build_object('eliminado', true, 'id', p_id);
END;
$function$;
