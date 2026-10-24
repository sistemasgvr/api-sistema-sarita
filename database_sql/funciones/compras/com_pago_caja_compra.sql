-- Function: com_pago_caja_compra
-- 20261023: el pago que una compra aporta a la caja, o NULL si no aporta ninguno.
--
-- Solo aporta una compra activa, AL CONTADO (sin CxP activa) y con medio de
-- pago: una al crédito mueve dinero al pagar su CxP (fin_pago), y las compras
-- al contado anteriores a esta fecha no tienen medio y no se reinterpretan como
-- efectivo, porque eso descuadraría el arqueo de cajas ya cerradas.
--
-- Mismo criterio que el bloque de compras al contado de fin_caja_calcular_totales.
-- Los que modifican una compra comparan este valor antes y después del cambio
-- (com_assert_caja_compra) para exigir la caja abierta solo cuando el cambio
-- toca de verdad el arqueo.

DROP FUNCTION IF EXISTS com_pago_caja_compra(p_id_comprobante integer);

CREATE OR REPLACE FUNCTION com_pago_caja_compra(p_id_comprobante integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
    SELECT jsonb_build_object(
        'idMedioPago', cc.id_medio_pago,
        'monto',       cc.total_importe,
        'fecha',       cc.fecha,
        'idSucursal',  cc.id_sucursal,
        'afectaCaja',  fin_medio_pago_flag(cc.id_medio_pago, 'AFECTA_CAJA')
    )
    FROM com_comprobante_compra cc
    WHERE cc.id = p_id_comprobante
      AND cc.estado = 1
      AND cc.id_medio_pago IS NOT NULL
      AND COALESCE(cc.total_importe, 0) > 0
      AND NOT EXISTS (
          SELECT 1
          FROM fin_cuenta fc
          WHERE fc.id_comprobante_compra = cc.id
            AND fc.estado = 1
      );
$function$;
