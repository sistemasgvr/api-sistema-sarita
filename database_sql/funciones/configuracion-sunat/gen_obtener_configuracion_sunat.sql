CREATE OR REPLACE FUNCTION gen_obtener_configuracion_sunat(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            cs.id,
            cs.id_empresa,
            e.nombre_comercial,
            e.ruc AS ruc_empresa,
            cs.usuario_sol,
            cs.clave_sol,
            cs.certificado_digital,
            cs.clave_certificado,
            (cs.clave_sol IS NOT NULL AND TRIM(cs.clave_sol) <> '') AS tiene_clave_sol,
            (cs.clave_certificado IS NOT NULL AND TRIM(cs.clave_certificado) <> '') AS tiene_clave_certificado,
            cs.id_ambiente,
            lo.nombre AS nombre_ambiente,
            cs.proveedor_pse,
            cs.pse_habilitado,
            cs.api_base_url,
            cs.api_token,
            (cs.api_token IS NOT NULL AND TRIM(cs.api_token) <> '') AS tiene_api_token,
            cs.api_usuario,
            cs.api_clave,
            (cs.api_clave IS NOT NULL AND TRIM(cs.api_clave) <> '') AS tiene_api_clave,
            COALESCE(NULLIF(TRIM(cs.ruc_emisor), ''), e.ruc) AS ruc_emisor,
            cs.client_id,
            cs.client_secret,
            (cs.client_secret IS NOT NULL AND TRIM(cs.client_secret) <> '') AS tiene_client_secret,
            cs.timeout_ms,
            cs.estado,
            cs.fecha_creacion,
            cs.fecha_modificacion,
            cs.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cs.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_configuracion_sunat cs
        INNER JOIN gen_empresa e ON cs.id_empresa = e.id
        LEFT JOIN gen_lista_opciones lo ON cs.id_ambiente = lo.id
        LEFT JOIN auth_usuarios uc ON cs.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON cs.id_usuario_modificacion = um.id
        WHERE cs.id = p_id AND cs.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
