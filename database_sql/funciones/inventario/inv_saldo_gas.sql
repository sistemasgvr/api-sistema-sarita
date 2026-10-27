-- Devuelve el stock de un producto gas en un almacén
DROP FUNCTION IF EXISTS public.inv_saldo_gas (p_id_producto_gas integer, p_id_almacen integer);

CREATE OR REPLACE FUNCTION public.inv_saldo_gas (p_id_producto_gas integer, p_id_almacen integer) RETURNS numeric LANGUAGE plpgsql STABLE AS $function$
BEGIN
    RETURN inv_stock_producto(p_id_producto_gas, p_id_almacen);
END;
$function$;
