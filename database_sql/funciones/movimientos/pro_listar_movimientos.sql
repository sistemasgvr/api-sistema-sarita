CREATE OR REPLACE FUNCTION pro_listar_movimientos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_producto INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_tipo_movimiento INTEGER DEFAULT NULL,
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
    FROM pro_movimientos m
    INNER JOIN pro_producto p ON m.id_producto = p.id
    INNER JOIN gen_almacen a ON m.id_almacen = a.id
    LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
    WHERE m.estado = 1
      AND (p_id_producto IS NULL OR m.id_producto = p_id_producto)
      AND (p_id_almacen IS NULL OR m.id_almacen = p_id_almacen)
      AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
      AND (p_fecha_desde IS NULL OR m.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR m.fecha <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(m.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(p.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(a.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(tm.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            m.id,
            m.fecha,
            m.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            m.id_almacen,
            a.nombre AS nombre_almacen,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.cantidad,
            m.stock_anterior,
            m.stock_nuevo,
            m.id_documento_ref,
            m.id_tipo_documento_ref,
            tdr.nombre AS nombre_tipo_documento_ref,
            m.glosa,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            m.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM pro_movimientos m
        INNER JOIN pro_producto p ON m.id_producto = p.id
        INNER JOIN gen_almacen a ON m.id_almacen = a.id
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tdr ON m.id_tipo_documento_ref = tdr.id
        LEFT JOIN auth_usuarios uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON m.id_usuario_modificacion = um.id
        WHERE m.estado = 1
          AND (p_id_producto IS NULL OR m.id_producto = p_id_producto)
          AND (p_id_almacen IS NULL OR m.id_almacen = p_id_almacen)
          AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
          AND (p_fecha_desde IS NULL OR m.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR m.fecha <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(m.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.codigo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(a.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(tm.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY m.fecha DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
