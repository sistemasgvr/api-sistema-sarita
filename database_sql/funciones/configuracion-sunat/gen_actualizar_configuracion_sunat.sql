CREATE OR REPLACE FUNCTION gen_actualizar_configuracion_sunat(
    p_id INTEGER,
    p_id_empresa INTEGER DEFAULT NULL,
    p_usuario_sol VARCHAR DEFAULT NULL,
    p_clave_sol VARCHAR DEFAULT NULL,
    p_certificado_digital VARCHAR DEFAULT NULL,
    p_clave_certificado VARCHAR DEFAULT NULL,
    p_id_ambiente INTEGER DEFAULT NULL,
    p_proveedor_pse VARCHAR DEFAULT NULL,
    p_pse_habilitado BOOLEAN DEFAULT NULL,
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
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_configuracion_sunat
    SET
        id_empresa = COALESCE(p_id_empresa, id_empresa),
        usuario_sol = COALESCE(p_usuario_sol, usuario_sol),
        clave_sol = COALESCE(p_clave_sol, clave_sol),
        certificado_digital = COALESCE(p_certificado_digital, certificado_digital),
        clave_certificado = COALESCE(p_clave_certificado, clave_certificado),
        id_ambiente = COALESCE(p_id_ambiente, id_ambiente),
        proveedor_pse = CASE
            WHEN p_proveedor_pse IS NULL THEN proveedor_pse
            ELSE NULLIF(TRIM(p_proveedor_pse), '')
        END,
        pse_habilitado = COALESCE(p_pse_habilitado, pse_habilitado),
        api_base_url = CASE
            WHEN p_api_base_url IS NULL THEN api_base_url
            ELSE NULLIF(TRIM(p_api_base_url), '')
        END,
        api_token = CASE
            WHEN p_api_token IS NULL THEN api_token
            WHEN TRIM(p_api_token) = '' THEN api_token
            ELSE TRIM(p_api_token)
        END,
        api_usuario = CASE
            WHEN p_api_usuario IS NULL THEN api_usuario
            ELSE NULLIF(TRIM(p_api_usuario), '')
        END,
        api_clave = CASE
            WHEN p_api_clave IS NULL THEN api_clave
            WHEN TRIM(p_api_clave) = '' THEN api_clave
            ELSE TRIM(p_api_clave)
        END,
        ruc_emisor = CASE
            WHEN p_ruc_emisor IS NULL THEN ruc_emisor
            ELSE NULLIF(TRIM(p_ruc_emisor), '')
        END,
        client_id = CASE
            WHEN p_client_id IS NULL THEN client_id
            ELSE NULLIF(TRIM(p_client_id), '')
        END,
        client_secret = CASE
            WHEN p_client_secret IS NULL THEN client_secret
            WHEN TRIM(p_client_secret) = '' THEN client_secret
            ELSE TRIM(p_client_secret)
        END,
        timeout_ms = COALESCE(p_timeout_ms, timeout_ms),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_configuracion_sunat(p_id);
END;
$function$;
