-- Devuelve el pago que una compra al contado aporta a la caja, o NULL
DROP FUNCTION IF EXISTS public.com_pago_caja_compra (p_id_comprobante integer);

CREATE OR REPLACE FUNCTION public.com_pago_caja_compra (p_id_comprobante integer) RETURNS jsonb LANGUAGE sql STABLE AS $function$
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
