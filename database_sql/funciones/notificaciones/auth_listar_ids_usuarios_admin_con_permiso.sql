-- Function: auth_listar_ids_usuarios_admin_con_permiso
--
-- Corregido en Fase 3: la función estaba declarada STABLE y ejecutaba
-- `SET TIME ZONE 'America/Lima'`, cosa que PostgreSQL rechaza en ejecución
-- ("SET is not allowed in a non-volatile function"). Es decir, fallaba en
-- *toda* llamada, incluida la de notificaciones.model.ts. Como aquí solo se
-- consultan ids de usuario, no hay ningún valor dependiente de la zona horaria:
-- se quita el SET y se mantiene STABLE.

DROP FUNCTION IF EXISTS auth_listar_ids_usuarios_admin_con_permiso(p_permiso character varying);

CREATE OR REPLACE FUNCTION auth_listar_ids_usuarios_admin_con_permiso(p_permiso character varying)
 RETURNS json
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_ids JSON;
BEGIN
    SELECT COALESCE(json_agg(DISTINCT u.id ORDER BY u.id), '[]'::JSON)
    INTO v_ids
    FROM auth_usuarios u
    INNER JOIN auth_usuarios_roles ur ON ur.id_usuario = u.id AND ur.estado = TRUE
    INNER JOIN auth_roles r ON r.id = ur.id_rol AND r.estado = TRUE AND r.nombre = 'Administrador'
    INNER JOIN auth_roles_permisos rp ON rp.id_rol = r.id AND rp.estado = TRUE
    INNER JOIN auth_permisos p ON p.id = rp.id_permiso AND p.estado = TRUE
    WHERE u.estado = TRUE
      AND (
          p.nombre = TRIM(p_permiso)
          OR p.nombre = 'auth.todo'
      );

    RETURN json_build_object('ids', v_ids);
END;
$function$;
