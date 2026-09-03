-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_inventario_resumen
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.956Z
DROP FUNCTION IF EXISTS dash_inventario_resumen(p_id_almacen integer);

CREATE OR REPLACE FUNCTION dash_inventario_resumen(p_id_almacen integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_valor_total NUMERIC(14,2);
    v_margen_prom NUMERIC(6,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(SUM(s.stock * p.precio_compra), 0)
    INTO v_valor_total
    FROM pro_stock s
    JOIN pro_producto p ON p.id = s.id_producto
    WHERE s.estado = 1
      AND p.estado = 1
      AND (p_id_almacen IS NULL OR s.id_almacen = p_id_almacen);

    SELECT ROUND(AVG((p.precio - p.precio_compra) / p.precio * 100), 2)
    INTO v_margen_prom
    FROM pro_producto p
    WHERE p.estado = 1
      AND COALESCE(p.es_servicio, FALSE) = FALSE
      AND p.precio > 0;

    RETURN json_build_object(
        'valorTotalInventario', v_valor_total,
        'margenPromedio', COALESCE(v_margen_prom, 0)
    );
END;
$function$;
