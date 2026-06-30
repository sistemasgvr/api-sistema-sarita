CREATE OR REPLACE FUNCTION gen_listar_configuraciones_servicio(
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
    FROM gen_configuracion_servicio cs
    WHERE cs.estado = 1
      AND (
          p_busqueda = ''
          OR LOWER(cs.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(cs.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cs.usuario, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cs.email, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cs.url, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            cs.id,
            cs.codigo,
            cs.nombre,
            cs.usuario,
            (cs.contrasena IS NOT NULL AND TRIM(cs.contrasena) <> '') AS tiene_contrasena,
            cs.email,
            cs.url,
            cs.observacion,
            cs.estado,
            cs.fecha_creacion,
            cs.fecha_modificacion,
            cs.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cs.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_configuracion_servicio cs
        LEFT JOIN auth_usuarios uc ON cs.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON cs.id_usuario_modificacion = um.id
        WHERE cs.estado = 1
          AND (
              p_busqueda = ''
              OR LOWER(cs.codigo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(cs.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cs.usuario, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cs.email, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cs.url, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY cs.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
