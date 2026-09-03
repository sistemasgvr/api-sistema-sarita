-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_crear_rol
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.942Z
DROP FUNCTION IF EXISTS auth_crear_rol(p_nombre character varying, p_descripcion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION auth_crear_rol(p_nombre character varying, p_descripcion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO auth_roles (nombre, descripcion, id_usuario_creacion, id_usuario_modificacion)
    VALUES (p_nombre, p_descripcion, p_id_usuario_auditoria, p_id_usuario_auditoria)
    RETURNING id INTO v_id;

    RETURN auth_obtener_rol(v_id);
END;
$function$;
