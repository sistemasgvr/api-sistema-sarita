-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_crear_usuario
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.942Z
DROP FUNCTION IF EXISTS auth_crear_usuario(p_nombre character varying, p_correo character varying, p_contrasena character varying, p_id_trabajador integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION auth_crear_usuario(p_nombre character varying, p_correo character varying, p_contrasena character varying, p_id_trabajador integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_trabajador IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM tra_trabajadores WHERE id = p_id_trabajador AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El trabajador indicado no existe.', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM auth_usuarios WHERE LOWER(correo) = LOWER(p_correo) AND estado = TRUE) THEN
        RETURN json_build_object('error', 'El correo ya está registrado', 'registro', NULL);
    END IF;

    IF p_id_trabajador IS NOT NULL AND EXISTS (
        SELECT 1 FROM auth_usuarios WHERE id_trabajador = p_id_trabajador AND estado = TRUE
    ) THEN
        RETURN json_build_object('error', 'El trabajador ya tiene un usuario de acceso.', 'registro', NULL);
    END IF;

    INSERT INTO auth_usuarios (nombre, correo, contrasena, id_trabajador)
    VALUES (p_nombre, LOWER(p_correo), p_contrasena, p_id_trabajador)
    RETURNING id INTO v_id;

    RETURN auth_obtener_usuario(v_id);
END;
$function$;
