-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_valor_total_inventario
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.660Z
DROP FUNCTION IF EXISTS dash_valor_total_inventario(p_id_almacen integer, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION dash_valor_total_inventario(p_id_almacen integer DEFAULT NULL::integer, p_limite integer DEFAULT 20, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_valor_total NUMERIC(14,4) := 0;
    v_total_items_stock BIGINT := 0;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT 
        COALESCE(SUM(ps.stock * COALESCE(NULLIF(p.precio_compra, 0), p.precio, 0)), 0),
        COUNT(*)
    INTO v_valor_total, v_total_items_stock
    FROM pro_stock ps
    INNER JOIN pro_producto p ON ps.id_producto = p.id
    WHERE ps.estado = 1 
      AND p.estado = 1 
      AND ps.stock > 0
      AND (p_id_almacen IS NULL OR ps.id_almacen = p_id_almacen);

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT 
            ps.id AS id_stock,
            p.codigo,
            p.nombre AS producto,
            a.nombre AS almacen,
            ps.stock,
            COALESCE(NULLIF(p.precio_compra, 0), p.precio, 0) AS costo_unitario,
            ROUND(ps.stock * COALESCE(NULLIF(p.precio_compra, 0), p.precio, 0), 2) AS valor_total_item
        FROM pro_stock ps
        INNER JOIN pro_producto p ON ps.id_producto = p.id
        INNER JOIN gen_almacen a ON ps.id_almacen = a.id
        WHERE ps.estado = 1 
          AND p.estado = 1 
          AND ps.stock > 0
          AND (p_id_almacen IS NULL OR ps.id_almacen = p_id_almacen)
        ORDER BY valor_total_item DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'valorTotalInventario', ROUND(v_valor_total, 2),
        'totalItemsEnStock', v_total_items_stock,
        'registros', v_registros
    );
END;
$function$
