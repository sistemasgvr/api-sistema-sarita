CREATE OR REPLACE FUNCTION auth_listar_roles(
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
    FROM auth_roles r
    WHERE r.estado = TRUE
      AND (
          p_busqueda = ''
          OR LOWER(r.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(r.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            r.id,
            r.nombre,
            r.descripcion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion,
            r.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            r.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT COUNT(*)::BIGINT
                FROM auth_roles_permisos rp
                WHERE rp.id_rol = r.id AND rp.estado = TRUE
            ) AS cantidad_permisos,
            (
                SELECT COUNT(*)::BIGINT
                FROM auth_usuarios_roles ur
                WHERE ur.id_rol = r.id AND ur.estado = TRUE
            ) AS cantidad_usuarios
        FROM auth_roles r
        LEFT JOIN auth_usuarios uc ON r.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON r.id_usuario_modificacion = um.id
        WHERE r.estado = TRUE
          AND (
              p_busqueda = ''
              OR LOWER(r.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(r.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY r.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
