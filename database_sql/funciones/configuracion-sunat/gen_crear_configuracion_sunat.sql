CREATE OR REPLACE FUNCTION gen_crear_configuracion_sunat(
    p_id_empresa INTEGER,
    p_usuario_sol VARCHAR,
    p_clave_sol VARCHAR,
    p_certificado_digital VARCHAR DEFAULT NULL,
    p_clave_certificado VARCHAR DEFAULT NULL,
    p_id_ambiente INTEGER DEFAULT NULL,
    p_proveedor_pse VARCHAR DEFAULT NULL,
    p_pse_habilitado BOOLEAN DEFAULT TRUE,
    p_api_base_url VARCHAR DEFAULT NULL,
    p_api_token TEXT DEFAULT NULL,
    p_api_usuario VARCHAR DEFAULT NULL,
    p_api_clave VARCHAR DEFAULT NULL,
    p_ruc_emisor VARCHAR DEFAULT NULL,
    p_client_id VARCHAR DEFAULT NULL,
    p_client_secret VARCHAR DEFAULT NULL,
    p_timeout_ms INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
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
$function$;
