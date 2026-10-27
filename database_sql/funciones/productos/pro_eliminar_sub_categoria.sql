-- Elimina (lógicamente) sub categoria
DROP FUNCTION IF EXISTS public.pro_eliminar_sub_categoria (p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.pro_eliminar_sub_categoria (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (
        SELECT 1 FROM pro_producto
        WHERE id_sub_categoria = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar la subcategoría porque tiene productos activos'
        );
    END IF;

    UPDATE pro_sub_categoria
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
