CREATE OR REPLACE FUNCTION auth_listar_usuarios(
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
    FROM auth_usuarios u
    WHERE u.estado = TRUE
      AND (
          p_busqueda = ''
          OR LOWER(u.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(u.correo) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            u.id,
            u.nombre,
            u.correo,
            u.estado,
            u.fecha_creacion,
            u.fecha_modificacion,
            (
                SELECT COALESCE(json_agg(json_build_object(
                    'id', r.id,
                    'nombre', r.nombre
                )), '[]'::JSON)
                FROM auth_usuarios_roles ur
                INNER JOIN auth_roles r ON ur.id_rol = r.id
                WHERE ur.id_usuario = u.id AND ur.estado = TRUE AND r.estado = TRUE
            ) AS roles
        FROM auth_usuarios u
        WHERE u.estado = TRUE
          AND (
              p_busqueda = ''
              OR LOWER(u.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(u.correo) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY u.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
