-- Quita (lógicamente) un permiso de un rol
DROP FUNCTION IF EXISTS public.auth_quitar_rol_permiso (p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.auth_quitar_rol_permiso (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE auth_roles_permisos
    SET estado = FALSE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = TRUE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
