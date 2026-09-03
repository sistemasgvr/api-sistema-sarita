-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_ganancias_del_dia
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.956Z
DROP FUNCTION IF EXISTS dash_ganancias_del_dia(p_fecha date, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION dash_ganancias_del_dia(p_fecha date DEFAULT CURRENT_DATE, p_limite integer DEFAULT 20, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_ganancia_total NUMERIC(12,4) := 0;
    v_total_items BIGINT := 0;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT 
        COALESCE(SUM(vd.importe - (COALESCE(cp.costo_producto, 0) * vd.cantidad)), 0),
        COUNT(*)
    INTO v_ganancia_total, v_total_items
    FROM ven_comprobante_detalle vd
    INNER JOIN ven_comprobante v ON vd.id_comprobante = v.id
    LEFT JOIN pro_catalogo_precio cp ON vd.id_producto = cp.id_producto
    WHERE v.fecha = p_fecha AND v.estado = 1 AND vd.estado = 1;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT 
            vd.id,
            CONCAT(v.serie, '-', v.numero) AS comprobante,
            p.nombre AS producto,
            vd.cantidad,
            vd.precio_unitario,
            vd.importe AS venta_total,
            COALESCE(cp.costo_producto, 0) AS costo_unitario,
            (COALESCE(cp.costo_producto, 0) * vd.cantidad) AS costo_total,
            (vd.importe - (COALESCE(cp.costo_producto, 0) * vd.cantidad)) AS ganancia_neta
        FROM ven_comprobante_detalle vd
        INNER JOIN ven_comprobante v ON vd.id_comprobante = v.id
        INNER JOIN pro_producto p ON vd.id_producto = p.id
        LEFT JOIN pro_catalogo_precio cp ON vd.id_producto = cp.id_producto
        WHERE v.fecha = p_fecha AND v.estado = 1 AND vd.estado = 1
        ORDER BY ganancia_neta DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'gananciaTotal', v_ganancia_total,
        'totalItemsVendidos', v_total_items,
        'registros', v_registros
    );
END;
$function$;
