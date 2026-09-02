-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_actualizar_configuracion_servicio
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.695Z
DROP FUNCTION IF EXISTS gen_actualizar_configuracion_servicio(p_id integer, p_codigo character varying, p_nombre character varying, p_usuario character varying, p_contrasena character varying, p_email character varying, p_url character varying, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_actualizar_configuracion_servicio(p_id integer, p_codigo character varying DEFAULT NULL::character varying, p_nombre character varying DEFAULT NULL::character varying, p_usuario character varying DEFAULT NULL::character varying, p_contrasena character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_url character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_configuracion_servicio
    SET
        codigo = COALESCE(p_codigo, codigo),
        nombre = COALESCE(p_nombre, nombre),
        usuario = COALESCE(p_usuario, usuario),
        contrasena = COALESCE(p_contrasena, contrasena),
        email = COALESCE(p_email, email),
        url = COALESCE(p_url, url),
        observacion = COALESCE(p_observacion, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_configuracion_servicio(p_id);
END;
$function$
