DROP FUNCTION IF EXISTS com_listar_compras;

CREATE OR REPLACE FUNCTION com_listar_compras(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_id_tipo_comprobante INTEGER DEFAULT NULL,
    p_id_tipo_registro INTEGER DEFAULT NULL
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
    FROM com_comprobante_compra c
    LEFT JOIN cli_clientes p ON c.id_proveedor = p.id
    WHERE c.estado = 1
      AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
      AND (p_id_proveedor IS NULL OR c.id_proveedor = p_id_proveedor)
      AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
      AND (p_id_tipo_registro IS NULL OR c.id_tipo_registro = p_id_tipo_registro)
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(c.serie, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.numero, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(p.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            c.id,
            c.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            c.serie,
            c.numero,
            c.fecha,
            c.id_proveedor,
            p.razon_social AS razon_social_proveedor,
            p.numero_documento AS doc_proveedor,
            c.id_tipo_registro,
            tr.nombre AS nombre_tipo_registro,
            c.id_categoria_gasto,
            cg.nombre AS nombre_categoria_gasto,
            c.id_sucursal,
            s.nombre AS nombre_sucursal,
            c.id_almacen,
            a.nombre AS nombre_almacen,
            c.id_moneda,
            m.nombre AS nombre_moneda,
            c.id_condicion_pago,
            cp.nombre AS nombre_condicion_pago,
            c.sub_total,
            c.igv,
            c.total_importe,
            c.afecta_inventario,
            c.declarar_sunat,
            c.glosa,
            c.id_estado,
            ec.nombre AS nombre_estado,
            c.fecha_creacion,
            c.fecha_modificacion
        FROM com_comprobante_compra c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN gen_lista_opciones tr ON c.id_tipo_registro = tr.id
        LEFT JOIN gen_lista_opciones cg ON c.id_categoria_gasto = cg.id
        LEFT JOIN gen_lista_opciones m ON c.id_moneda = m.id
        LEFT JOIN gen_lista_opciones ec ON c.id_estado = ec.id
        LEFT JOIN cli_clientes p ON c.id_proveedor = p.id
        LEFT JOIN gen_sucursal s ON c.id_sucursal = s.id
        LEFT JOIN gen_almacen a ON c.id_almacen = a.id
        LEFT JOIN gen_condicion_pago cp ON c.id_condicion_pago = cp.id
        WHERE c.estado = 1
          AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
          AND (p_id_proveedor IS NULL OR c.id_proveedor = p_id_proveedor)
          AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
          AND (p_id_tipo_registro IS NULL OR c.id_tipo_registro = p_id_tipo_registro)
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(c.serie, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.numero, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(p.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY c.fecha DESC, c.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;