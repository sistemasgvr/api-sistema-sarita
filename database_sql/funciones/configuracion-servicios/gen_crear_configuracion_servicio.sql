-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_configuracion_servicio
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.705Z
DROP FUNCTION IF EXISTS gen_crear_configuracion_servicio(p_codigo character varying, p_nombre character varying, p_usuario character varying, p_contrasena character varying, p_email character varying, p_url character varying, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_configuracion_servicio(p_codigo character varying, p_nombre character varying, p_usuario character varying DEFAULT NULL::character varying, p_contrasena character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_url character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_configuracion_servicio (
        codigo,
        nombre,
        usuario,
        contrasena,
        email,
        url,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_codigo,
        p_nombre,
        p_usuario,
        p_contrasena,
        p_email,
        p_url,
        p_observacion,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_configuracion_servicio(v_id);
END;
$function$
