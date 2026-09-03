-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_actualizar_usuario
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.941Z
DROP FUNCTION IF EXISTS auth_actualizar_usuario(p_id integer, p_nombre character varying, p_correo character varying, p_contrasena character varying, p_id_trabajador integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION auth_actualizar_usuario(p_id integer, p_nombre character varying DEFAULT NULL::character varying, p_correo character varying DEFAULT NULL::character varying, p_contrasena character varying DEFAULT NULL::character varying, p_id_trabajador integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_correo IS NOT NULL AND EXISTS (
        SELECT 1 FROM auth_usuarios
        WHERE LOWER(correo) = LOWER(p_correo) AND id <> p_id AND estado = TRUE
    ) THEN
        RETURN json_build_object('error', 'El correo ya está registrado', 'registro', NULL);
    END IF;

    IF p_id_trabajador IS NOT NULL AND EXISTS (
        SELECT 1 FROM auth_usuarios
        WHERE id_trabajador = p_id_trabajador AND id <> p_id AND estado = TRUE
    ) THEN
        RETURN json_build_object('error', 'El trabajador ya tiene otro usuario de acceso.', 'registro', NULL);
    END IF;

    UPDATE auth_usuarios
    SET
        nombre = COALESCE(p_nombre, nombre),
        correo = COALESCE(LOWER(p_correo), correo),
        contrasena = COALESCE(p_contrasena, contrasena),
        id_trabajador = COALESCE(p_id_trabajador, id_trabajador),
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = TRUE;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN auth_obtener_usuario(p_id);
END;
$function$;
