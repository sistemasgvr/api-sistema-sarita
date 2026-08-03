-- ¿esta compra tiene líneas que ya afectaron stock?
-- Si devuelve TRUE, la compra NO admite modificación parcial:
-- ni agregar/quitar línea, ni cambiar cantidad, ni tocar cabecera.
CREATE OR REPLACE FUNCTION com_tiene_movimientos_inventario(
    p_id_comprobante INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $function$
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