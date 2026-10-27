-- Indica si una compra tiene líneas que afectan stock
DROP FUNCTION IF EXISTS public.com_tiene_movimientos_inventario (p_id_comprobante integer);

CREATE OR REPLACE FUNCTION public.com_tiene_movimientos_inventario (p_id_comprobante integer) RETURNS boolean LANGUAGE plpgsql AS $function$
DECLARE
    v_tiene BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM com_comprobante_compra_detalle
        WHERE id_comprobante = p_id_comprobante
          AND afecta_stock = TRUE
          AND estado = 1
    ) INTO v_tiene;
 
    RETURN v_tiene;
END;
$function$;
