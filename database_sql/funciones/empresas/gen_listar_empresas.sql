CREATE OR REPLACE FUNCTION gen_listar_empresas(
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
    FROM gen_empresa e
    WHERE e.estado = 1
      AND (
          p_busqueda = ''
          OR LOWER(e.ruc) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(e.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(e.nombre_comercial, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(e.email, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            e.id,
            e.ruc,
            e.razon_social,
            e.nombre_comercial,
            e.direccion,
            e.telefono,
            e.email,
            e.estado,
            e.fecha_creacion,
            e.fecha_modificacion,
            e.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            e.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_empresa e
        LEFT JOIN auth_usuarios uc ON e.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON e.id_usuario_modificacion = um.id
        WHERE e.estado = 1
          AND (
              p_busqueda = ''
              OR LOWER(e.ruc) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(e.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(e.nombre_comercial, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(e.email, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY e.nombre_comercial ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
