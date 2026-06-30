CREATE OR REPLACE FUNCTION gen_listar_condiciones_pago(
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
    FROM gen_condicion_pago cp
    WHERE cp.estado = 1
      AND (
          p_busqueda = ''
          OR LOWER(cp.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(cp.nombre) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            cp.id,
            cp.codigo,
            cp.nombre,
            cp.dias_credito,
            cp.estado,
            cp.fecha_creacion,
            cp.fecha_modificacion,
            cp.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cp.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_condicion_pago cp
        LEFT JOIN auth_usuarios uc ON cp.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON cp.id_usuario_modificacion = um.id
        WHERE cp.estado = 1
          AND (
              p_busqueda = ''
              OR LOWER(cp.codigo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(cp.nombre) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY cp.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
