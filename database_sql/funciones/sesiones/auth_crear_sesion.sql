-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_crear_sesion
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.490Z
DROP FUNCTION IF EXISTS auth_crear_sesion(p_id_usuario integer, p_token character varying, p_ip character varying, p_user_agent character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION auth_crear_sesion(p_id_usuario integer, p_token character varying, p_ip character varying DEFAULT NULL::character varying, p_user_agent character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO auth_sesiones (
        id_usuario, token, ip, user_agent,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_usuario, p_token, p_ip, p_user_agent,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN auth_obtener_sesion(v_id);
END;
$function$
