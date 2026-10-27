-- Elimina (lógicamente) una solicitud de baja de cliente
DROP FUNCTION IF EXISTS public.cli_eliminar_baja_cliente (p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.cli_eliminar_baja_cliente (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE cli_baja_cliente
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
