-- Function: ven_pagos_de_comprobante
-- Fase 3 — fuente única de "cómo se cobró esta venta".
--
-- Devuelve las líneas de ven_comprobante_pago (cobro multi-medio) y, si el
-- comprobante todavía no tiene ninguna, una línea sintética a partir de la
-- cabecera. Así cada consumidor (totales de caja, libro diario, resúmenes)
-- escribe una sola consulta y funciona igual con comprobantes anteriores a la
-- Fase 3 que con los nuevos.

DROP FUNCTION IF EXISTS ven_pagos_de_comprobante(p_id_comprobante integer);

CREATE OR REPLACE FUNCTION ven_pagos_de_comprobante(p_id_comprobante integer)
 RETURNS TABLE (
    id_pago integer,
    item integer,
    id_medio_pago integer,
    id_cuenta_bancaria integer,
    monto numeric,
    numero_operacion character varying,
    origen text
 )
 LANGUAGE sql
 STABLE
AS $function$
    SELECT
        p.id,
        p.item,
        p.id_medio_pago,
        p.id_cuenta_bancaria,
        p.monto,
        p.numero_operacion,
        'DETALLE'::text
    FROM ven_comprobante_pago p
    WHERE p.id_comprobante = p_id_comprobante
      AND p.estado = 1

    UNION ALL

    SELECT
        NULL::integer,
        1,
        c.id_medio_pago,
        NULL::integer,
        c.total_importe,
        NULL::character varying,
        'CABECERA'::text
    FROM ven_comprobante c
    WHERE c.id = p_id_comprobante
      AND NOT EXISTS (
          SELECT 1 FROM ven_comprobante_pago p2
          WHERE p2.id_comprobante = c.id AND p2.estado = 1
      );
$function$;
