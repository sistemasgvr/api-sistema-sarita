CREATE OR REPLACE FUNCTION bal_listar_movimientos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_tipo_movimiento INTEGER DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
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
    FROM bal_movimiento m
    INNER JOIN bal_balon b ON m.id_balon = b.id
    LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
    WHERE m.estado = 1
      AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
      AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
      AND (p_id_cliente IS NULL OR m.id_cliente = p_id_cliente)
      AND (p_fecha_desde IS NULL OR m.fecha_movimiento::DATE >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR m.fecha_movimiento::DATE <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(tm.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(m.observacion, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            m.id,
            m.id_balon,
            b.codigo_balon,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.id_documento_ref,
            m.id_tipo_documento_ref,
            tdr.nombre AS nombre_tipo_documento_ref,
            m.id_cliente,
            c.razon_social AS nombre_cliente,
            m.id_almacen_origen,
            ao.nombre AS nombre_almacen_origen,
            m.id_almacen_destino,
            ad.nombre AS nombre_almacen_destino,
            m.fecha_movimiento,
            m.observacion,
            m.estado,
            m.fecha_creacion,
            (
                m.id_documento_ref IS NULL
                AND NOT EXISTS (
                    SELECT 1 FROM bal_baja_balon bb
                    WHERE bb.id_movimiento = m.id AND bb.estado = 1
                )
            ) AS puede_eliminar
        FROM bal_movimiento m
        INNER JOIN bal_balon b ON m.id_balon = b.id
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tdr ON m.id_tipo_documento_ref = tdr.id
        LEFT JOIN cli_clientes c ON m.id_cliente = c.id
        LEFT JOIN gen_almacen ao ON m.id_almacen_origen = ao.id
        LEFT JOIN gen_almacen ad ON m.id_almacen_destino = ad.id
        WHERE m.estado = 1
          AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
          AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
          AND (p_id_cliente IS NULL OR m.id_cliente = p_id_cliente)
          AND (p_fecha_desde IS NULL OR m.fecha_movimiento::DATE >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR m.fecha_movimiento::DATE <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(tm.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(m.observacion, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY m.fecha_movimiento DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
