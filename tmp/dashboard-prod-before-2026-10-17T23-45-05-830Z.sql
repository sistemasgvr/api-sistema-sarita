-- Respaldo previo de las seis funciones del dashboard.
BEGIN;
CREATE OR REPLACE FUNCTION public.dash_demanda_gases(p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Antes: dos sentencias SELECT separadas reutilizaban el mismo WITH ("detalle_gas"),
    -- pero un CTE solo existe dentro de la sentencia que lo declara; la segunda sentencia
    -- fallaba en tiempo de ejecución con "relation detalle_gas does not exist" y la
    -- función nunca llegó a devolver datos. Se une todo en una sola sentencia.
    WITH detalle_gas AS (
        SELECT
            p.id AS id_producto,
            p.nombre,
            SUM(vcd.cantidad) AS cantidad
        FROM ven_comprobante_detalle vcd
        JOIN ven_comprobante vc ON vc.id = vcd.id_comprobante
        JOIN pro_producto p ON p.id = vcd.id_producto
        WHERE vcd.estado = 1
          AND vc.estado = 1
          AND vc.id_tipo_comprobante IN (102, 104, 192)
          AND COALESCE(p.es_gas, FALSE) = TRUE
          AND (p_fecha_desde IS NULL OR vc.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR vc.fecha <= p_fecha_hasta)
        GROUP BY p.id, p.nombre
    ),
    totales AS (
        SELECT COALESCE(SUM(cantidad), 0) AS total FROM detalle_gas
    )
    SELECT json_build_object(
        'totalCantidad', (SELECT total FROM totales),
        'detalle', COALESCE(json_agg(
            json_build_object(
                'idProducto', d.id_producto,
                'producto', d.nombre,
                'cantidad', d.cantidad,
                'porcentaje', CASE WHEN t.total > 0 THEN ROUND(d.cantidad / t.total * 100, 2) ELSE 0 END
            )
            ORDER BY d.cantidad DESC
        ), '[]'::json)
    )
    INTO v_result
    FROM detalle_gas d
    CROSS JOIN totales t;

    RETURN v_result;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.dash_historico_ventas_compras(p_anio integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_anio   INT := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INT);
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH meses AS (
        SELECT generate_series(1, 12) AS mes
    ),
    ventas AS (
        SELECT EXTRACT(MONTH FROM vc.fecha)::INT AS mes, SUM(vc.total_importe) AS total
        FROM ven_comprobante vc
        WHERE vc.estado = 1
          AND vc.id_tipo_comprobante IN (102, 104, 192)
          AND EXTRACT(YEAR FROM vc.fecha) = v_anio
        GROUP BY 1
    ),
    compras AS (
        SELECT EXTRACT(MONTH FROM cc.fecha)::INT AS mes, SUM(cc.total_importe) AS total
        FROM com_comprobante_compra cc
        WHERE cc.estado = 1
          AND EXTRACT(YEAR FROM cc.fecha) = v_anio
        GROUP BY 1
    )
    SELECT json_build_object(
        'anio', v_anio,
        'meses', json_agg(
            json_build_object(
                'mes', m.mes,
                'nombreMes', TO_CHAR(TO_DATE(m.mes::text, 'MM'), 'Mon'),
                'ventas', COALESCE(v.total, 0),
                'compras', COALESCE(c.total, 0)
            )
            ORDER BY m.mes
        )
    )
    INTO v_result
    FROM meses m
    LEFT JOIN ventas v ON v.mes = m.mes
    LEFT JOIN compras c ON c.mes = m.mes;

    RETURN v_result;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.dash_top_clientes_venta(p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_limite integer DEFAULT 10)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_desde  DATE := COALESCE(p_fecha_desde, DATE_TRUNC('month', CURRENT_DATE)::date);
    v_hasta  DATE := COALESCE(p_fecha_hasta, (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::date);
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(t), '[]'::json)
    INTO v_result
    FROM (
        SELECT
            c.id AS "idCliente",
            COALESCE(c.razon_social, c.nombres) AS cliente,
            COUNT(DISTINCT vc.id) AS "cantidadComprobantes",
            SUM(vc.total_importe) AS "totalVenta"
        FROM ven_comprobante vc
        JOIN cli_clientes c ON c.id = vc.id_cliente
        WHERE vc.estado = 1
          AND vc.id_tipo_comprobante IN (102, 104, 192)
          AND vc.fecha >= v_desde
          AND vc.fecha <= v_hasta
        GROUP BY c.id, c.razon_social, c.nombres
        ORDER BY SUM(vc.total_importe) DESC
        LIMIT p_limite
    ) t;

    RETURN json_build_object(
        'fechaDesde', v_desde,
        'fechaHasta', v_hasta,
        'detalle', v_result
    );
END;
$function$
;
CREATE OR REPLACE FUNCTION public.dash_velocidad_salida(p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_id_almacen integer DEFAULT NULL::integer, p_limite integer DEFAULT 20)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
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
          AND vc.id_tipo_comprobante IN (102, 104, 192)
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
$function$
;
CREATE OR REPLACE FUNCTION public.dash_venta_gases_comparativo(p_anio integer DEFAULT NULL::integer, p_mes integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha_ref     DATE;
    v_inicio_actual DATE;
    v_fin_actual    DATE;
    v_inicio_ant    DATE;
    v_fin_ant       DATE;
    v_result        JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_fecha_ref := MAKE_DATE(
        COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INT),
        COALESCE(p_mes, EXTRACT(MONTH FROM CURRENT_DATE)::INT),
        1
    );

    v_inicio_actual := DATE_TRUNC('month', v_fecha_ref)::date;
    v_fin_actual    := (DATE_TRUNC('month', v_fecha_ref) + INTERVAL '1 month - 1 day')::date;
    v_inicio_ant    := (DATE_TRUNC('month', v_fecha_ref) - INTERVAL '1 month')::date;
    v_fin_ant       := (v_inicio_actual - INTERVAL '1 day')::date;

    WITH ventas_gas AS (
        SELECT
            p.id AS id_producto,
            p.nombre,
            SUM(vcd.cantidad) FILTER (WHERE vc.fecha BETWEEN v_inicio_actual AND v_fin_actual) AS cantidad_actual,
            SUM(vcd.cantidad) FILTER (WHERE vc.fecha BETWEEN v_inicio_ant AND v_fin_ant) AS cantidad_anterior
        FROM ven_comprobante_detalle vcd
        JOIN ven_comprobante vc ON vc.id = vcd.id_comprobante
        JOIN pro_producto p ON p.id = vcd.id_producto
        WHERE vcd.estado = 1
          AND vc.estado = 1
          AND vc.id_tipo_comprobante IN (102, 104, 192)
          AND COALESCE(p.es_gas, FALSE) = TRUE
          AND vc.fecha BETWEEN v_inicio_ant AND v_fin_actual
        GROUP BY p.id, p.nombre
    )
    SELECT json_build_object(
        'mesActual', json_build_object('anio', EXTRACT(YEAR FROM v_inicio_actual), 'mes', EXTRACT(MONTH FROM v_inicio_actual)),
        'mesAnterior', json_build_object('anio', EXTRACT(YEAR FROM v_inicio_ant), 'mes', EXTRACT(MONTH FROM v_inicio_ant)),
        'detalle', COALESCE(json_agg(
            json_build_object(
                'idProducto', id_producto,
                'producto', nombre,
                'cantidadActual', COALESCE(cantidad_actual, 0),
                'cantidadAnterior', COALESCE(cantidad_anterior, 0)
            )
            ORDER BY COALESCE(cantidad_actual, 0) DESC
        ), '[]'::json)
    )
    INTO v_result
    FROM ventas_gas;

    RETURN v_result;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.dash_ventas_netas(p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_id_cliente integer DEFAULT NULL::integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total NUMERIC(14,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(SUM(total_importe), 0)
    INTO v_total
    FROM ven_comprobante
    WHERE estado = 1
      AND id_tipo_comprobante IN (102, 104, 192)
      AND (p_fecha_desde IS NULL OR fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR fecha <= p_fecha_hasta)
      AND (p_id_cliente IS NULL OR id_cliente = p_id_cliente);

    RETURN v_total;
END;
$function$
;
COMMIT;
