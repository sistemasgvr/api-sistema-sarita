-- Crea permiso
DROP FUNCTION IF EXISTS public.auth_crear_permiso (
  p_nombre character varying,
  p_descripcion character varying,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.auth_crear_permiso (
  p_nombre character varying,
  p_descripcion character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO auth_permisos (nombre, descripcion, id_usuario_creacion, id_usuario_modificacion)
    VALUES (p_nombre, p_descripcion, p_id_usuario_auditoria, p_id_usuario_auditoria)
    RETURNING id INTO v_id;

    RETURN auth_obtener_permiso(v_id);
END;
$function$;
