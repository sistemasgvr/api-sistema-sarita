-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_top_clientes_venta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.957Z
DROP FUNCTION IF EXISTS dash_top_clientes_venta(p_fecha_desde date, p_fecha_hasta date, p_limite integer);

CREATE OR REPLACE FUNCTION dash_top_clientes_venta(p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_limite integer DEFAULT 10)
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
$function$;
