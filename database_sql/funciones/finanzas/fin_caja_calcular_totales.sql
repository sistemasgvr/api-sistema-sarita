-- Calcula los totales de caja de un día (ventas, cobranzas, gastos, garantías) por medio de pago
DROP FUNCTION IF EXISTS public.fin_caja_calcular_totales (p_fecha date, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION public.fin_caja_calcular_totales (
  p_fecha date,
  p_id_sucursal integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_efectivo_id INT;
    v_ventas_contado NUMERIC(14,4) := 0;
    v_ventas_credito NUMERIC(14,4) := 0;
    v_ventas_caja NUMERIC(14,4) := 0;
    v_ventas_efectivo NUMERIC(14,4) := 0;
    v_ventas_otros NUMERIC(14,4) := 0;
    v_cobranzas NUMERIC(14,4) := 0;
    v_cobranzas_caja NUMERIC(14,4) := 0;
    v_cobranzas_efectivo NUMERIC(14,4) := 0;
    v_pagos_proveedor NUMERIC(14,4) := 0;
    v_pagos_proveedor_caja NUMERIC(14,4) := 0;
    v_gastos_caja NUMERIC(14,4) := 0;
    v_gastos_caja_medios NUMERIC(14,4) := 0;
    v_gastos_compra NUMERIC(14,4) := 0;
    v_depositos NUMERIC(14,4) := 0;
    v_garantias_cobro NUMERIC(14,4) := 0;
    v_garantias_cobro_caja NUMERIC(14,4) := 0;
    v_garantias_dev NUMERIC(14,4) := 0;
    v_garantias_dev_caja NUMERIC(14,4) := 0;
    v_por_medio JSON;
    v_efectivo_neto NUMERIC(14,4) := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT o.id INTO v_efectivo_id
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
    WHERE UPPER(o.nombre) = 'EFECTIVO'
    LIMIT 1;

    WITH mov AS (
        SELECT
            'VENTA'::TEXT AS tipo,
            COALESCE(pg.id_medio_pago, v_efectivo_id) AS id_medio_pago,
            pg.monto * CASE WHEN UPPER(COALESCE(tip.nombre, '')) = 'NOTA_CREDITO' THEN -1 ELSE 1 END AS monto
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        CROSS JOIN LATERAL ven_pagos_de_comprobante(c.id) pg
        WHERE c.estado = 1
          AND c.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND NOT EXISTS (
              SELECT 1
              FROM ven_comprobante ori
              JOIN gen_lista_opciones tori ON tori.id = ori.id_tipo_comprobante
              WHERE ori.id = c.id_comprobante_origen
                AND UPPER(COALESCE(tori.descripcion, '')) IN ('NV', 'VSD')
                AND COALESCE(tip.descripcion, '') IN ('01', '03')
          )

        UNION ALL

        SELECT
            CASE WHEN UPPER(tc.nombre) = 'COBRAR' THEN 'COBRANZA' ELSE 'PAGO_PROVEEDOR' END,
            COALESCE(p.id_medio_pago, v_efectivo_id),
            p.monto
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        WHERE p.estado = 1
          AND p.fecha_pago = p_fecha
          AND UPPER(tc.nombre) IN ('COBRAR', 'PAGAR')
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )

        UNION ALL

        SELECT 'PAGO_PROVEEDOR', cc.id_medio_pago, cc.total_importe
        FROM com_comprobante_compra cc
        WHERE cc.estado = 1
          AND cc.fecha = p_fecha
          AND cc.id_medio_pago IS NOT NULL
          AND COALESCE(cc.total_importe, 0) > 0
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
          AND NOT EXISTS (
              SELECT 1 FROM fin_cuenta fc
              WHERE fc.id_comprobante_compra = cc.id AND fc.estado = 1
          )

        UNION ALL

        SELECT 'GASTO', COALESCE(g.id_medio_pago, v_efectivo_id), g.monto
        FROM fin_caja_gasto g
        LEFT JOIN fin_caja_sesion s ON s.id = g.id_sesion AND s.estado = 1
        WHERE g.estado = 1 AND g.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)

        UNION ALL

        SELECT 'DEPOSITO', v_efectivo_id, d.monto
        FROM fin_caja_deposito d
        LEFT JOIN fin_caja_sesion s ON s.id = d.id_sesion AND s.estado = 1
        WHERE d.estado = 1 AND d.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)

        UNION ALL

        SELECT 'GARANTIA_COBRO', COALESCE(gm.id_medio_pago, g.id_medio_pago, v_efectivo_id), gm.monto
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_comprobante c ON c.id = gm.id_comprobante
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        WHERE gm.estado = 1
          AND gm.fecha = p_fecha
          AND UPPER(tm.nombre) = 'COBRO'
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(gm.id_sucursal, c.id_sucursal) = p_id_sucursal
          )

        UNION ALL

        SELECT
            'GARANTIA_DEVOLUCION',
            COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago, v_efectivo_id),
            gm.monto
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        WHERE gm.estado = 1
          AND gm.fecha = p_fecha
          AND UPPER(tm.nombre) = 'DEVOLUCION'
          AND (
              p_id_sucursal IS NULL
              OR gm.id_sucursal = p_id_sucursal
          )
    ),
    m AS (
        SELECT
            mov.tipo,
            mov.id_medio_pago,
            mov.monto,
            fin_medio_pago_flag(mov.id_medio_pago, 'ES_CREDITO')  AS es_credito,
            fin_medio_pago_flag(mov.id_medio_pago, 'AFECTA_CAJA') AS afecta_caja,
            fin_medio_pago_flag(mov.id_medio_pago, 'ES_EFECTIVO') AS es_efectivo
        FROM mov
    ),
    por_medio AS (
        SELECT
            m.id_medio_pago,
            BOOL_OR(m.es_efectivo) AS es_efectivo,
            BOOL_OR(m.afecta_caja) AS afecta_caja,
            SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA') AS ventas,
            SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA') AS cobranzas,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO') AS garantias_cobro,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO') AS gastos,
            SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR') AS pagos_proveedor,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION') AS garantias_devolucion,
            SUM(m.monto) FILTER (WHERE m.tipo = 'DEPOSITO') AS depositos
        FROM m
        WHERE NOT m.es_credito
        GROUP BY m.id_medio_pago
    )
    SELECT
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND NOT m.es_credito), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.es_credito), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND NOT m.es_credito AND NOT m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA' AND m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'DEPOSITO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION' AND m.afecta_caja), 0),
        COALESCE(SUM(CASE
            WHEN m.tipo IN ('VENTA', 'COBRANZA', 'GARANTIA_COBRO') THEN m.monto
            ELSE -m.monto END) FILTER (WHERE m.es_efectivo), 0),
        (
            SELECT COALESCE(json_agg(row_to_json(r) ORDER BY r.orden, r."medioPago"), '[]'::JSON)
            FROM (
                SELECT
                    pm.id_medio_pago AS "idMedioPago",
                    COALESCE(o.nombre, 'SIN MEDIO') AS "medioPago",
                    pm.es_efectivo AS "esEfectivo",
                    pm.afecta_caja AS "afectaCaja",
                    COALESCE(pm.ventas, 0) AS ventas,
                    COALESCE(pm.cobranzas, 0) AS cobranzas,
                    COALESCE(pm.garantias_cobro, 0) AS "garantiasCobro",
                    COALESCE(pm.gastos, 0) AS gastos,
                    COALESCE(pm.pagos_proveedor, 0) AS "pagosProveedor",
                    COALESCE(pm.garantias_devolucion, 0) AS "garantiasDevolucion",
                    COALESCE(pm.depositos, 0) AS depositos,
                    COALESCE(pm.ventas, 0) + COALESCE(pm.cobranzas, 0)
                        + COALESCE(pm.garantias_cobro, 0) AS ingresos,
                    COALESCE(pm.gastos, 0) + COALESCE(pm.pagos_proveedor, 0)
                        + COALESCE(pm.garantias_devolucion, 0) + COALESCE(pm.depositos, 0) AS egresos,
                    COALESCE(pm.ventas, 0) + COALESCE(pm.cobranzas, 0)
                        + COALESCE(pm.garantias_cobro, 0)
                        - COALESCE(pm.gastos, 0) - COALESCE(pm.pagos_proveedor, 0)
                        - COALESCE(pm.garantias_devolucion, 0) - COALESCE(pm.depositos, 0) AS neto,
                    COALESCE(cfg.orden, 999) AS orden
                FROM por_medio pm
                LEFT JOIN gen_lista_opciones o ON o.id = pm.id_medio_pago
                LEFT JOIN fin_medio_pago_config cfg ON cfg.id_medio_pago = pm.id_medio_pago
            ) r
        )
    INTO v_ventas_contado, v_ventas_credito, v_ventas_caja, v_ventas_efectivo, v_ventas_otros,
         v_cobranzas, v_cobranzas_caja, v_cobranzas_efectivo,
         v_pagos_proveedor, v_pagos_proveedor_caja,
         v_gastos_caja, v_gastos_caja_medios,
         v_depositos,
         v_garantias_cobro, v_garantias_cobro_caja,
         v_garantias_dev, v_garantias_dev_caja,
         v_efectivo_neto,
         v_por_medio
    FROM m;

    SELECT COALESCE(SUM(cc.total_importe), 0)
    INTO v_gastos_compra
    FROM com_comprobante_compra cc
    LEFT JOIN gen_lista_opciones tr ON tr.id = cc.id_tipo_registro
    WHERE cc.estado = 1
      AND cc.fecha = p_fecha
      AND UPPER(COALESCE(tr.nombre, '')) = 'GASTO'
      AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal);

    RETURN json_build_object(
        'ventasContado', v_ventas_contado,
        'ventasCredito', v_ventas_credito,
        'ventasMediosCaja', v_ventas_caja,
        'ventasEfectivo', v_ventas_efectivo,
        'ventasOtrosMedios', v_ventas_otros,
        'cobranzas', v_cobranzas,
        'cobranzasMediosCaja', v_cobranzas_caja,
        'cobranzasEfectivo', v_cobranzas_efectivo,
        'pagosProveedor', v_pagos_proveedor,
        'pagosProveedorMediosCaja', v_pagos_proveedor_caja,
        'gastosCaja', v_gastos_caja,
        'gastosCajaMediosCaja', v_gastos_caja_medios,
        'gastosCompra', v_gastos_compra,
        'gastos', v_gastos_caja + v_gastos_compra,
        'depositos', v_depositos,
        'garantiasCobro', v_garantias_cobro,
        'garantiasCobroMediosCaja', v_garantias_cobro_caja,
        'garantiasDevolucion', v_garantias_dev,
        'garantiasDevolucionMediosCaja', v_garantias_dev_caja,
        'efectivoNeto', v_efectivo_neto,
        'porMedio', v_por_medio
    );
END;
$function$;
