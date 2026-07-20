CREATE OR REPLACE FUNCTION gen_listar_configuraciones_sunat(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0
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
      AND (
          p_busqueda = ''
          OR LOWER(cs.usuario_sol) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(e.nombre_comercial, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(lo.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            cs.id,
            cs.id_empresa,
            e.nombre_comercial,
            cs.usuario_sol,
            cs.certificado_digital,
            (cs.clave_sol IS NOT NULL AND TRIM(cs.clave_sol) <> '') AS tiene_clave_sol,
            (cs.clave_certificado IS NOT NULL AND TRIM(cs.clave_certificado) <> '') AS tiene_clave_certificado,
            cs.client_id_gre,
            (cs.client_secret_gre IS NOT NULL AND TRIM(cs.client_secret_gre) <> '') AS tiene_client_secret_gre,
            cs.id_ambiente,
            lo.nombre AS nombre_ambiente,
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
          AND (
              p_busqueda = ''
              OR LOWER(cs.usuario_sol) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(e.nombre_comercial, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(lo.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY e.nombre_comercial ASC, cs.usuario_sol ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
