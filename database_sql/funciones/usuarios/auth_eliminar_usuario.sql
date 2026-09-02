-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_eliminar_usuario
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.493Z
DROP FUNCTION IF EXISTS auth_eliminar_usuario(p_id integer);

CREATE OR REPLACE FUNCTION auth_eliminar_usuario(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE auth_usuarios
    SET estado = FALSE, fecha_modificacion = NOW()
    WHERE id = p_id AND estado = TRUE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$
