CREATE OR REPLACE FUNCTION pro_listar_stock(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_solo_bajo_minimo BOOLEAN DEFAULT NULL
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
    FROM pro_stock s
    INNER JOIN gen_almacen a ON s.id_almacen = a.id
    INNER JOIN pro_producto p ON s.id_producto = p.id
    WHERE s.estado = 1
      AND a.estado = 1
      AND p.estado = 1
      AND (p_id_almacen IS NULL OR s.id_almacen = p_id_almacen)
      AND (p_id_producto IS NULL OR s.id_producto = p_id_producto)
      AND (
          p_solo_bajo_minimo IS NULL
          OR (p_solo_bajo_minimo = TRUE AND s.stock <= s.stock_minimo)
          OR (p_solo_bajo_minimo = FALSE AND s.stock > s.stock_minimo)
      )
      AND (
          p_busqueda = ''
          OR LOWER(a.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(p.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            s.id,
            s.id_almacen,
            a.nombre AS nombre_almacen,
            a.id_sucursal,
            suc.nombre AS nombre_sucursal,
            s.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            p.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            s.stock,
            s.stock_minimo,
            (s.stock <= s.stock_minimo) AS bajo_minimo,
            s.estado,
            s.fecha_creacion,
            s.fecha_modificacion,
            s.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            s.id_usuario_modificacion,
            um2.nombre AS nombre_usuario_modificacion
        FROM pro_stock s
        INNER JOIN gen_almacen a ON s.id_almacen = a.id
        INNER JOIN gen_sucursal suc ON a.id_sucursal = suc.id
        INNER JOIN pro_producto p ON s.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON p.id_unidad_medida = um.id
        LEFT JOIN auth_usuarios uc ON s.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um2 ON s.id_usuario_modificacion = um2.id
        WHERE s.estado = 1
          AND a.estado = 1
          AND p.estado = 1
          AND (p_id_almacen IS NULL OR s.id_almacen = p_id_almacen)
          AND (p_id_producto IS NULL OR s.id_producto = p_id_producto)
          AND (
              p_solo_bajo_minimo IS NULL
              OR (p_solo_bajo_minimo = TRUE AND s.stock <= s.stock_minimo)
              OR (p_solo_bajo_minimo = FALSE AND s.stock > s.stock_minimo)
          )
          AND (
              p_busqueda = ''
              OR LOWER(a.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.codigo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY a.nombre ASC, p.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
