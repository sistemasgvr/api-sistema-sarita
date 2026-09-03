-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_stock_producto
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.964Z
DROP FUNCTION IF EXISTS inv_stock_producto(p_id_producto integer, p_id_almacen integer);

CREATE OR REPLACE FUNCTION inv_stock_producto(p_id_producto integer, p_id_almacen integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_stock NUMERIC(12,4);
BEGIN
    SELECT stock INTO v_stock
    FROM pro_stock
    WHERE id_producto = p_id_producto AND id_almacen = p_id_almacen AND estado = 1;

    RETURN COALESCE(v_stock, 0);
END;
$function$;
