-- Dashboard: cantidad vendida frente a stock actual por producto en un rango
DROP FUNCTION IF EXISTS public.dash_velocidad_salida (
  p_fecha_desde date,
  p_fecha_hasta date,
  p_id_almacen integer,
  p_limite integer
);

CREATE OR REPLACE FUNCTION public.dash_velocidad_salida (
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_id_almacen integer DEFAULT NULL::integer,
  p_limite integer DEFAULT 20
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH stock_prod AS (
        SELECT
            s.id_producto,
            SUM(s.stock) AS stock_actual
        FROM pro_stock s
        WHERE s.estado = 1
          AND (p_id_almacen IS NULL OR s.id_almacen = p_id_almacen)
        GROUP BY s.id_producto
    ),
    ventas_prod AS (
        SELECT
            vcd.id_producto,
            SUM(vcd.cantidad) AS cantidad_vendida
        FROM ven_comprobante_detalle vcd
        JOIN ven_comprobante vc ON vc.id = vcd.id_comprobante
        WHERE vcd.estado = 1
          AND vc.estado = 1
          AND EXISTS (
              SELECT 1
              FROM gen_lista_opciones tipo
              JOIN gen_lista lista ON lista.id = tipo.id_lista AND lista.nombre = 'TipoComprobante'
              JOIN gen_lista_opciones interno ON interno.id = vc.id_estado
              JOIN gen_lista lista_interno ON lista_interno.id = interno.id_lista AND lista_interno.nombre = 'EstadoDocumento'
              JOIN gen_lista_opciones sunat ON sunat.id = vc.id_estado_sunat
              JOIN gen_lista lista_sunat ON lista_sunat.id = sunat.id_lista AND lista_sunat.nombre = 'EstadoSunat'
              WHERE tipo.id = vc.id_tipo_comprobante
                AND interno.nombre IN ('PENDIENTE', 'PAGADO')
                AND (
                    (tipo.descripcion IN ('01', '03') AND sunat.nombre = 'ACEPTADO')
                    OR (tipo.descripcion = 'VSD' AND sunat.nombre = 'NO_APLICA')
                )
          )
          AND (p_fecha_desde IS NULL OR vc.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR vc.fecha <= p_fecha_hasta)
        GROUP BY vcd.id_producto
    ),
    calculo AS (
        SELECT
            p.id AS id_producto,
            p.nombre AS producto,
            COALESCE(c.nombre, 'Sin categoría') AS categoria,
            COALESCE(sp.stock_actual, 0) AS stock_actual,
            COALESCE(vp.cantidad_vendida, 0) AS cantidad_vendida,
            CASE WHEN COALESCE(sp.stock_actual, 0) > 0
                THEN ROUND(COALESCE(vp.cantidad_vendida, 0) / sp.stock_actual, 2)
                ELSE NULL
            END AS rotacion,
            CASE WHEN p.precio > 0
                THEN ROUND((p.precio - p.precio_compra) / p.precio * 100, 2)
                ELSE NULL
            END AS margen_unitario
        FROM pro_producto p
        LEFT JOIN pro_sub_categoria sc ON sc.id = p.id_sub_categoria
        LEFT JOIN pro_categoria c ON c.id = sc.id_categoria
        LEFT JOIN stock_prod sp ON sp.id_producto = p.id
        LEFT JOIN ventas_prod vp ON vp.id_producto = p.id
        WHERE p.estado = 1
          AND COALESCE(p.es_servicio, FALSE) = FALSE
          AND COALESCE(p.afecta_stock, TRUE) = TRUE
    )
    SELECT COALESCE(json_agg(t), '[]'::json)
    INTO v_result
    FROM (
        SELECT
            id_producto AS "idProducto",
            producto,
            categoria,
            stock_actual AS "stockActual",
            cantidad_vendida AS "cantidadVendida",
            rotacion,
            CASE
                WHEN rotacion IS NULL THEN 'SIN_STOCK'
                WHEN rotacion >= 8 THEN 'MUY_ALTA'
                WHEN rotacion >= 4 THEN 'ALTA'
                WHEN rotacion >= 1.5 THEN 'MEDIA'
                ELSE 'BAJA'
            END AS "nivelRotacion",
            margen_unitario AS "margenUnitario"
        FROM calculo
        ORDER BY rotacion DESC NULLS LAST
        LIMIT p_limite
    ) t;

    RETURN json_build_object('detalle', v_result);
END;
$function$;
