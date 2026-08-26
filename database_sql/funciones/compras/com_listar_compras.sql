DROP FUNCTION IF EXISTS com_listar_compras(VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER, DATE, DATE, INTEGER);

CREATE OR REPLACE FUNCTION com_listar_compras(
    p_busqueda        VARCHAR DEFAULT '',
    p_limite          INTEGER DEFAULT 10,
    p_offset          INTEGER DEFAULT 0,
    p_id_proveedor    INTEGER DEFAULT NULL,
    p_id_almacen      INTEGER DEFAULT NULL,
    p_fecha_desde     DATE DEFAULT NULL,
    p_fecha_hasta     DATE DEFAULT NULL,
    p_estado          INTEGER DEFAULT NULL,
    p_id_tipo_registro    INTEGER DEFAULT NULL,
    p_id_categoria_gasto  INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total     BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM com_comprobante_compra c
    LEFT JOIN cli_clientes pr ON pr.id = c.id_proveedor
    WHERE (p_id_proveedor IS NULL OR c.id_proveedor = p_id_proveedor)
      AND (p_id_almacen IS NULL OR c.id_almacen = p_id_almacen)
      AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
      AND (p_estado IS NULL OR c.estado = p_estado)
      AND (p_id_tipo_registro IS NULL OR c.id_tipo_registro = p_id_tipo_registro)
      AND (p_id_categoria_gasto IS NULL OR c.id_categoria_gasto = p_id_categoria_gasto)
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(c.serie, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.numero, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.nombres, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.apellido_paterno, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_registros
    FROM (
        SELECT
            c.id, c.serie, c.numero, c.fecha,
            c.id_proveedor,
            COALESCE(
                NULLIF(TRIM(pr.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pr.nombres, pr.apellido_paterno, pr.apellido_materno)), ''),
                pr.numero_documento
            ) AS nombre_proveedor,
            c.id_almacen, alm.nombre AS almacen,
            c.id_tipo_registro, tr.nombre AS tipo_registro,
            c.id_categoria_gasto, cat.nombre AS categoria_gasto,
            c.sub_total, c.total_importe,
            c.estado,
            com_tiene_movimientos_inventario(c.id) AS tiene_movimientos_inventario,
            c.id_comprobante_referencia
        FROM com_comprobante_compra c
        LEFT JOIN cli_clientes pr ON pr.id = c.id_proveedor
        LEFT JOIN gen_almacen alm ON alm.id = c.id_almacen
        LEFT JOIN gen_lista_opciones tr ON tr.id = c.id_tipo_registro
        LEFT JOIN gen_lista_opciones cat ON cat.id = c.id_categoria_gasto
        WHERE (p_id_proveedor IS NULL OR c.id_proveedor = p_id_proveedor)
          AND (p_id_almacen IS NULL OR c.id_almacen = p_id_almacen)
          AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
          AND (p_estado IS NULL OR c.estado = p_estado)
          AND (p_id_tipo_registro IS NULL OR c.id_tipo_registro = p_id_tipo_registro)
          AND (p_id_categoria_gasto IS NULL OR c.id_categoria_gasto = p_id_categoria_gasto)
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(c.serie, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.numero, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.nombres, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.apellido_paterno, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY c.fecha DESC, c.id DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
