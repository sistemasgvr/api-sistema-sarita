CREATE OR REPLACE FUNCTION gen_listar_sucursales(
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
    FROM gen_sucursal s
    WHERE s.estado = 1
      AND (
          p_busqueda = ''
          OR LOWER(s.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(s.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(s.direccion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(s.telefono, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            s.id,
            s.codigo,
            s.nombre,
            s.direccion,
            s.id_departamento,
            dep.nombre AS nombre_departamento,
            s.id_provincia,
            prov.nombre AS nombre_provincia,
            s.id_distrito,
            dist.nombre AS nombre_distrito,
            s.telefono,
            s.estado,
            s.fecha_creacion,
            s.fecha_modificacion,
            s.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            s.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_sucursal s
        LEFT JOIN gen_departamento dep ON dep.id = s.id_departamento
        LEFT JOIN gen_provincia prov ON prov.id = s.id_provincia
        LEFT JOIN gen_distrito dist ON dist.id = s.id_distrito
        LEFT JOIN auth_usuarios uc ON s.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON s.id_usuario_modificacion = um.id
        WHERE s.estado = 1
          AND (
              p_busqueda = ''
              OR LOWER(s.codigo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(s.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(s.direccion, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(s.telefono, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY s.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
