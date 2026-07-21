CREATE OR REPLACE FUNCTION gen_listar_configuraciones_sunat(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_empresa INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM gen_configuracion_sunat cs
    INNER JOIN gen_empresa e ON cs.id_empresa = e.id
    LEFT JOIN gen_lista_opciones lo ON cs.id_ambiente = lo.id
    WHERE cs.estado = 1
      AND (p_id_empresa IS NULL OR cs.id_empresa = p_id_empresa)
      AND (
          p_busqueda = ''
          OR LOWER(cs.usuario_sol) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(e.nombre_comercial, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(lo.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cs.proveedor_pse, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
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
        WHERE cs.estado = 1
          AND (p_id_empresa IS NULL OR cs.id_empresa = p_id_empresa)
          AND (
              p_busqueda = ''
              OR LOWER(cs.usuario_sol) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(e.nombre_comercial, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(lo.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cs.proveedor_pse, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY e.nombre_comercial ASC, cs.usuario_sol ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
