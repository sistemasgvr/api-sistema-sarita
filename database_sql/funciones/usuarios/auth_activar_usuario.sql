-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_activar_usuario
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.483Z
DROP FUNCTION IF EXISTS auth_activar_usuario(p_id integer);

CREATE OR REPLACE FUNCTION auth_activar_usuario(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE auth_usuarios
    SET estado = TRUE, fecha_modificacion = NOW()
    WHERE id = p_id AND estado = FALSE;

    IF NOT FOUND THEN
        RETURN json_build_object('activado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('activado', TRUE, 'id', p_id);
END;
$function$
