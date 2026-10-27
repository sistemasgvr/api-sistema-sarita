-- Devuelve el stock de un producto en un almacén (0 si no existe)
DROP FUNCTION IF EXISTS public.inv_stock_producto (p_id_producto integer, p_id_almacen integer);

CREATE OR REPLACE FUNCTION public.inv_stock_producto (p_id_producto integer, p_id_almacen integer) RETURNS numeric LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_stock NUMERIC(12,4);
BEGIN
    SELECT stock INTO v_stock
    FROM pro_stock
    WHERE id_producto = p_id_producto AND id_almacen = p_id_almacen AND estado = 1;

    RETURN COALESCE(v_stock, 0);
END;
$function$;
