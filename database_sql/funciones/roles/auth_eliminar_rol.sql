-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_eliminar_rol
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.492Z
DROP FUNCTION IF EXISTS auth_eliminar_rol(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION auth_eliminar_rol(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE auth_roles
    SET estado = FALSE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = TRUE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$
