-- Saldo actual de un producto en un almacén (punto único de consulta de stock).
CREATE OR REPLACE FUNCTION inv_stock_producto(p_id_producto INTEGER, p_id_almacen INTEGER)
RETURNS NUMERIC
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
