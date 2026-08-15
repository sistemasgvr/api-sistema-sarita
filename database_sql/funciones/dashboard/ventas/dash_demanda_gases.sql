DROP FUNCTION IF EXISTS dash_demanda_gases(DATE, DATE);

CREATE OR REPLACE FUNCTION dash_demanda_gases(
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_total  NUMERIC(14,4);
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

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
    )
    SELECT COALESCE(SUM(cantidad), 0) INTO v_total FROM detalle_gas;

    SELECT json_build_object(
        'totalCantidad', v_total,
        'detalle', COALESCE(json_agg(
            json_build_object(
                'idProducto', id_producto,
                'producto', nombre,
                'cantidad', cantidad,
                'porcentaje', CASE WHEN v_total > 0 THEN ROUND(cantidad / v_total * 100, 2) ELSE 0 END
            )
            ORDER BY cantidad DESC
        ), '[]'::json)
    )
    INTO v_result
    FROM detalle_gas;

    RETURN v_result;
END;
$$;
