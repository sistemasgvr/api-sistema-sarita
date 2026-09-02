-- Alias semántico de inv_stock_producto para productos de gas (mismo pro_stock).
-- Pensado como reemplazo directo de bal_listar_stock_gas / bal_capacidad_disponible_balon
-- cuando esos flujos se corten hacia inv_movimiento (hito 4 del roadmap de Fase 1).
CREATE OR REPLACE FUNCTION inv_saldo_gas(p_id_producto_gas INTEGER, p_id_almacen INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $function$
BEGIN
    RETURN inv_stock_producto(p_id_producto_gas, p_id_almacen);
END;
$function$;
