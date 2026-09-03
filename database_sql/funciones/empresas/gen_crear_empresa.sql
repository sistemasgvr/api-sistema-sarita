-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_empresa
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.961Z
DROP FUNCTION IF EXISTS gen_crear_empresa(p_ruc character varying, p_razon_social character varying, p_nombre_comercial character varying, p_direccion character varying, p_telefono character varying, p_email character varying, p_id_usuario_auditoria integer, p_tolerancia_m3_ruta_pueblo numeric, p_psi_minimo_util numeric);

CREATE OR REPLACE FUNCTION gen_crear_empresa(p_ruc character varying, p_razon_social character varying DEFAULT NULL::character varying, p_nombre_comercial character varying DEFAULT NULL::character varying, p_direccion character varying DEFAULT NULL::character varying, p_telefono character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_tolerancia_m3_ruta_pueblo numeric DEFAULT NULL::numeric, p_psi_minimo_util numeric DEFAULT NULL::numeric)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_empresa (
        ruc,
        razon_social,
        nombre_comercial,
        direccion,
        telefono,
        email,
        tolerancia_m3_ruta_pueblo,
        psi_minimo_util,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_ruc,
        p_razon_social,
        p_nombre_comercial,
        p_direccion,
        p_telefono,
        p_email,
        p_tolerancia_m3_ruta_pueblo,
        p_psi_minimo_util,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_empresa(v_id);
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;
