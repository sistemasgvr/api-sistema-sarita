-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_obtener_sesion
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.506Z
DROP FUNCTION IF EXISTS auth_obtener_sesion(p_id integer);

CREATE OR REPLACE FUNCTION auth_obtener_sesion(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.id_usuario,
            u.nombre AS nombre_usuario,
            u.correo,
            s.ip,
            s.user_agent,
            s.fecha_inicio,
            s.fecha_fin,
            s.estado,
            s.fecha_creacion
        FROM auth_sesiones s
        INNER JOIN auth_usuarios u ON s.id_usuario = u.id
        WHERE s.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$
