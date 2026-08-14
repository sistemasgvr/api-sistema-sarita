CREATE OR REPLACE FUNCTION fin_cuenta_documento_tiene_pagos(
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_comprobante_compra INTEGER DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $function$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM fin_pago p
        JOIN fin_cuenta c ON c.id = p.id_cuenta
        WHERE p.estado = 1
          AND c.estado = 1
          AND (
              (
                  p_id_comprobante_venta IS NOT NULL
                  AND (
                      c.id_comprobante_venta = p_id_comprobante_venta
                      OR c.id_cuenta_padre IN (
                          SELECT fc.id
                          FROM fin_cuenta fc
                          WHERE fc.id_comprobante_venta = p_id_comprobante_venta
                            AND fc.estado = 1
                            AND fc.id_cuenta_padre IS NULL
                      )
                  )
              )
              OR (
                  p_id_comprobante_compra IS NOT NULL
                  AND (
                      c.id_comprobante_compra = p_id_comprobante_compra
                      OR c.id_cuenta_padre IN (
                          SELECT fc.id
                          FROM fin_cuenta fc
                          WHERE fc.id_comprobante_compra = p_id_comprobante_compra
                            AND fc.estado = 1
                            AND fc.id_cuenta_padre IS NULL
                      )
                  )
              )
          )
    );
END;
$function$;
