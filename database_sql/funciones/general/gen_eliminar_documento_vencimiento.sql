-- Elimina (lógicamente) documento vencimiento
DROP FUNCTION IF EXISTS public.gen_eliminar_documento_vencimiento (p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.gen_eliminar_documento_vencimiento (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_documento_vencimiento
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
