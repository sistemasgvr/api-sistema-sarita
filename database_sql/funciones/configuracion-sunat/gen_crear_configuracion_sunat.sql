-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_configuracion_sunat
-- Overloads: 2
-- Generated: 2026-09-02T21:31:03.705Z
DROP FUNCTION IF EXISTS gen_crear_configuracion_sunat(p_id_empresa integer, p_usuario_sol character varying, p_clave_sol character varying, p_certificado_digital character varying, p_clave_certificado character varying, p_id_ambiente integer, p_proveedor_pse character varying, p_pse_habilitado boolean, p_api_base_url character varying, p_api_token text, p_api_usuario character varying, p_api_clave character varying, p_ruc_emisor character varying, p_client_id character varying, p_client_secret character varying, p_timeout_ms integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_configuracion_sunat(p_id_empresa integer, p_usuario_sol character varying, p_clave_sol character varying, p_certificado_digital character varying DEFAULT NULL::character varying, p_clave_certificado character varying DEFAULT NULL::character varying, p_id_ambiente integer DEFAULT NULL::integer, p_proveedor_pse character varying DEFAULT NULL::character varying, p_pse_habilitado boolean DEFAULT true, p_api_base_url character varying DEFAULT NULL::character varying, p_api_token text DEFAULT NULL::text, p_api_usuario character varying DEFAULT NULL::character varying, p_api_clave character varying DEFAULT NULL::character varying, p_ruc_emisor character varying DEFAULT NULL::character varying, p_client_id character varying DEFAULT NULL::character varying, p_client_secret character varying DEFAULT NULL::character varying, p_timeout_ms integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_configuracion_sunat (
        id_empresa,
        usuario_sol,
        clave_sol,
        certificado_digital,
        clave_certificado,
        id_ambiente,
        proveedor_pse,
        pse_habilitado,
        api_base_url,
        api_token,
        api_usuario,
        api_clave,
        ruc_emisor,
        client_id,
        client_secret,
        timeout_ms,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_empresa,
        p_usuario_sol,
        p_clave_sol,
        p_certificado_digital,
        p_clave_certificado,
        p_id_ambiente,
        NULLIF(TRIM(p_proveedor_pse), ''),
        COALESCE(p_pse_habilitado, TRUE),
        NULLIF(TRIM(p_api_base_url), ''),
        NULLIF(TRIM(p_api_token), ''),
        NULLIF(TRIM(p_api_usuario), ''),
        NULLIF(TRIM(p_api_clave), ''),
        NULLIF(TRIM(p_ruc_emisor), ''),
        NULLIF(TRIM(p_client_id), ''),
        NULLIF(TRIM(p_client_secret), ''),
        p_timeout_ms,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_configuracion_sunat(v_id);
END;
$function$

DROP FUNCTION IF EXISTS gen_crear_configuracion_sunat(p_id_empresa integer, p_usuario_sol character varying, p_clave_sol character varying, p_certificado_digital character varying, p_clave_certificado character varying, p_id_ambiente integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_configuracion_sunat(p_id_empresa integer, p_usuario_sol character varying, p_clave_sol character varying, p_certificado_digital character varying DEFAULT NULL::character varying, p_clave_certificado character varying DEFAULT NULL::character varying, p_id_ambiente integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_configuracion_sunat (
        id_empresa,
        usuario_sol,
        clave_sol,
        certificado_digital,
        clave_certificado,
        id_ambiente,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_empresa,
        p_usuario_sol,
        p_clave_sol,
        p_certificado_digital,
        p_clave_certificado,
        p_id_ambiente,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_configuracion_sunat(v_id);
END;
$function$
