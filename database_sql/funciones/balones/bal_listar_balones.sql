CREATE OR REPLACE FUNCTION bal_listar_balones(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_tipo_balon INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_estado_balon INTEGER DEFAULT NULL,
    p_id_cliente_ubicacion INTEGER DEFAULT NULL
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
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
    LEFT JOIN gen_almacen a ON b.id_almacen = a.id
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    WHERE b.estado = 1
      AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
      AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
      AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
      AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
      AND (
          p_busqueda = ''
          OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(b.libro_cilindro, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(tb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(a.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            b.id,
            b.codigo_balon,
            b.libro_cilindro,
            b.pagina_libro,
            b.fecha_registro,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.id_cliente_ubicacion,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.fecha_proxima_prueba_hidrostatica,
            b.presion_actual,
            b.estado,
            b.fecha_creacion,
            b.fecha_modificacion
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN gen_almacen a ON b.id_almacen = a.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        WHERE b.estado = 1
          AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
          AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
          AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
          AND (
              p_busqueda = ''
              OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.libro_cilindro, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(tb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(a.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY b.codigo_balon ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
