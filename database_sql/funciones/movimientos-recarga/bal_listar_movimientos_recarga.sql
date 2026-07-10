CREATE OR REPLACE FUNCTION bal_listar_movimientos_recarga(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
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
    FROM bal_movimiento_recarga mr
    INNER JOIN bal_balon b ON mr.id_balon = b.id
    LEFT JOIN cli_clientes cli ON mr.id_cliente = cli.id
    LEFT JOIN gen_lista_opciones tr ON mr.id_tipo_recarga = tr.id
    WHERE mr.estado = 1
      AND (p_id_balon IS NULL OR mr.id_balon = p_id_balon)
      AND (p_id_almacen IS NULL OR mr.id_almacen = p_id_almacen)
      AND (p_fecha_desde IS NULL OR mr.fecha_salida_almacen >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR mr.fecha_salida_almacen <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cli.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(mr.numero_guia_salida, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(mr.numero_factura, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(tr.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            mr.id,
            mr.fecha_salida_almacen,
            mr.id_balon,
            b.codigo_balon,
            mr.id_cliente,
            cli.razon_social AS nombre_cliente,
            mr.id_tipo_recarga,
            tr.nombre AS tipo_recarga_nombre,
            mr.id_producto,
            p.nombre AS nombre_producto,
            mr.capacidad,
            mr.serie_guia_salida,
            mr.numero_guia_salida,
            mr.serie_factura,
            mr.numero_factura,
            mr.id_comprobante,
            mr.fecha_llegada_almacen,
            mr.id_almacen,
            a.nombre AS nombre_almacen,
            mr.estado,
            mr.fecha_creacion
        FROM bal_movimiento_recarga mr
        INNER JOIN bal_balon b ON mr.id_balon = b.id
        LEFT JOIN cli_clientes cli ON mr.id_cliente = cli.id
        LEFT JOIN gen_lista_opciones tr ON mr.id_tipo_recarga = tr.id
        LEFT JOIN pro_producto p ON mr.id_producto = p.id
        LEFT JOIN gen_almacen a ON mr.id_almacen = a.id
        WHERE mr.estado = 1
          AND (p_id_balon IS NULL OR mr.id_balon = p_id_balon)
          AND (p_id_almacen IS NULL OR mr.id_almacen = p_id_almacen)
          AND (p_fecha_desde IS NULL OR mr.fecha_salida_almacen >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR mr.fecha_salida_almacen <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cli.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(mr.numero_guia_salida, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(mr.numero_factura, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(tr.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY mr.fecha_salida_almacen DESC, mr.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
