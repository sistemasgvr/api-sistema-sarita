CREATE OR REPLACE FUNCTION gen_listar_almacenes(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_sucursal INTEGER DEFAULT NULL
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
    FROM gen_almacen a
    INNER JOIN gen_sucursal s ON a.id_sucursal = s.id
    WHERE a.estado = 1
      AND (p_id_sucursal IS NULL OR a.id_sucursal = p_id_sucursal)
      AND (
          p_busqueda = ''
          OR LOWER(a.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(a.ubicacion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(a.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(s.nombre) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            a.id,
            a.id_sucursal,
            s.nombre AS nombre_sucursal,
            a.nombre,
            a.ubicacion,
            a.descripcion,
            a.id_departamento,
            a.id_provincia,
            a.id_distrito,
            a.estado,
            a.fecha_creacion,
            a.fecha_modificacion,
            a.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            a.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_almacen a
        INNER JOIN gen_sucursal s ON a.id_sucursal = s.id
        LEFT JOIN auth_usuarios uc ON a.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON a.id_usuario_modificacion = um.id
        WHERE a.estado = 1
          AND (p_id_sucursal IS NULL OR a.id_sucursal = p_id_sucursal)
          AND (
              p_busqueda = ''
              OR LOWER(a.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(a.ubicacion, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(a.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(s.nombre) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY a.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
