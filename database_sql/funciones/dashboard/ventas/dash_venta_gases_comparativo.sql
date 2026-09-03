-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_venta_gases_comparativo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.957Z
DROP FUNCTION IF EXISTS dash_venta_gases_comparativo(p_anio integer, p_mes integer);

CREATE OR REPLACE FUNCTION dash_venta_gases_comparativo(p_anio integer DEFAULT NULL::integer, p_mes integer DEFAULT NULL::integer)
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
$function$;
