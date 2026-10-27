-- Elimina (lógicamente) catalogo precio
DROP FUNCTION IF EXISTS public.pro_eliminar_catalogo_precio (p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.pro_eliminar_catalogo_precio (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE pro_catalogo_precio
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
