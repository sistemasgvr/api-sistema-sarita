-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_cerrar_sesion
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.488Z
DROP FUNCTION IF EXISTS auth_cerrar_sesion(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION auth_cerrar_sesion(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE auth_sesiones
    SET estado = FALSE,
        fecha_fin = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = TRUE AND fecha_fin IS NULL;

    IF NOT FOUND THEN
        RETURN json_build_object('cerrada', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('cerrada', TRUE, 'id', p_id);
END;
$function$
