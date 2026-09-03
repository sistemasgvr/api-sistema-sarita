-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_saldo_gas
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.964Z
DROP FUNCTION IF EXISTS inv_saldo_gas(p_id_producto_gas integer, p_id_almacen integer);

CREATE OR REPLACE FUNCTION inv_saldo_gas(p_id_producto_gas integer, p_id_almacen integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN inv_stock_producto(p_id_producto_gas, p_id_almacen);
END;
$function$;
