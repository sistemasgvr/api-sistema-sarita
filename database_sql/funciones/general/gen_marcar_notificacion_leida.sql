-- Marca como leída una notificación de un usuario
DROP FUNCTION IF EXISTS public.gen_marcar_notificacion_leida (
  p_id integer,
  p_id_usuario integer,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.gen_marcar_notificacion_leida (
  p_id integer,
  p_id_usuario integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_notificacion
    SET leida = TRUE,
        fecha_lectura = COALESCE(fecha_lectura, NOW()),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND id_usuario = p_id_usuario
      AND estado = 1
      AND leida = FALSE;

    IF NOT FOUND THEN
        RETURN gen_obtener_notificacion(p_id, p_id_usuario);
    END IF;

    RETURN gen_obtener_notificacion(p_id, p_id_usuario);
END;
$function$;
