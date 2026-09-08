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
        CASE
            WHEN COALESCE(cp.dias_credito, 0) > 0
              OR COALESCE(cp.numero_cuotas, 0) > 1
            THEN (
                SELECT o.id FROM gen_lista_opciones o
                JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
                WHERE UPPER(o.nombre) = 'CREDITO' LIMIT 1
            )
            ELSE c.id_medio_pago
        END,
        NULL::integer,
        c.total_importe,
        NULL::character varying,
        'CABECERA'::text
    FROM ven_comprobante c
    LEFT JOIN gen_condicion_pago cp ON cp.id = c.id_condicion_pago
    WHERE c.id = p_id_comprobante
      AND NOT EXISTS (
          SELECT 1 FROM ven_comprobante_pago p2
          WHERE p2.id_comprobante = c.id AND p2.estado = 1
      );
$function$;
