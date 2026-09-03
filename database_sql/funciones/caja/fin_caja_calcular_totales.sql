-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_caja_calcular_totales
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS fin_caja_calcular_totales(p_fecha date, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION fin_caja_calcular_totales(p_fecha date, p_id_sucursal integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_ventas_contado NUMERIC(14,4) := 0;
    v_ventas_credito NUMERIC(14,4) := 0;
    v_ventas_caja NUMERIC(14,4) := 0;
    v_cobranzas NUMERIC(14,4) := 0;
    v_cobranzas_caja NUMERIC(14,4) := 0;
    v_gastos_caja NUMERIC(14,4) := 0;
    v_gastos_compra NUMERIC(14,4) := 0;
    v_depositos NUMERIC(14,4) := 0;
    v_garantias_cobro NUMERIC(14,4) := 0;
    v_garantias_cobro_caja NUMERIC(14,4) := 0;
    v_garantias_dev NUMERIC(14,4) := 0;
    v_garantias_dev_caja NUMERIC(14,4) := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COALESCE(SUM(CASE WHEN COALESCE(UPPER(mp.nombre), '') <> 'CREDITO' THEN c.total_importe ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN UPPER(mp.nombre) = 'CREDITO' THEN c.total_importe ELSE 0 END), 0),
        COALESCE(SUM(CASE
            WHEN UPPER(COALESCE(mp.nombre, 'EFECTIVO')) IN ('EFECTIVO', 'YAPE', 'PLIN')
            THEN c.total_importe ELSE 0 END), 0)
    INTO v_ventas_contado, v_ventas_credito, v_ventas_caja
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones mp ON mp.id = c.id_medio_pago
    LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
    LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
    WHERE c.estado = 1
      AND c.fecha = p_fecha
      AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal OR c.id_sucursal IS NULL)
      AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
      AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO');

    SELECT
        COALESCE(SUM(p.monto), 0),
        COALESCE(SUM(CASE
            WHEN UPPER(COALESCE(mp.nombre, 'EFECTIVO')) IN ('EFECTIVO', 'YAPE', 'PLIN')
            THEN p.monto ELSE 0 END), 0)
    INTO v_cobranzas, v_cobranzas_caja
    FROM fin_pago p
    INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
    INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
    LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
    WHERE p.estado = 1
      AND p.fecha_pago = p_fecha
      AND UPPER(tc.nombre) = 'COBRAR'
      AND (
          p_id_sucursal IS NULL
          OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
      );

    SELECT COALESCE(SUM(g.monto), 0)
    INTO v_gastos_caja
    FROM fin_caja_gasto g
    LEFT JOIN fin_caja_sesion s ON s.id = g.id_sesion AND s.estado = 1
    WHERE g.estado = 1 AND g.fecha = p_fecha
      AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal);

    SELECT COALESCE(SUM(cc.total_importe), 0)
    INTO v_gastos_compra
    FROM com_comprobante_compra cc
    LEFT JOIN gen_lista_opciones tr ON tr.id = cc.id_tipo_registro
    WHERE cc.estado = 1
      AND cc.fecha = p_fecha
      AND UPPER(COALESCE(tr.nombre, '')) = 'GASTO'
      AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal OR cc.id_sucursal IS NULL);

    SELECT COALESCE(SUM(d.monto), 0)
    INTO v_depositos
    FROM fin_caja_deposito d
    LEFT JOIN fin_caja_sesion s ON s.id = d.id_sesion AND s.estado = 1
    WHERE d.estado = 1 AND d.fecha = p_fecha
      AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal);

    -- Cobros de garantía que no viajan ya en el total del CPE (factura/boleta/NV)
    SELECT
        COALESCE(SUM(gm.monto), 0),
        COALESCE(SUM(CASE
            WHEN UPPER(COALESCE(mp.nombre, 'EFECTIVO')) IN ('EFECTIVO', 'YAPE', 'PLIN')
            THEN gm.monto ELSE 0 END), 0)
    INTO v_garantias_cobro, v_garantias_cobro_caja
    FROM ven_garantia_movimiento gm
    INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
    LEFT JOIN ven_comprobante c ON c.id = gm.id_comprobante
    LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
    LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
    LEFT JOIN gen_lista_opciones mp ON mp.id = COALESCE(gm.id_medio_pago, g.id_medio_pago)
    WHERE gm.estado = 1
      AND gm.fecha = p_fecha
      AND UPPER(tm.nombre) = 'COBRO'
      AND (
          p_id_sucursal IS NULL
          OR COALESCE(gm.id_sucursal, c.id_sucursal) = p_id_sucursal
          OR COALESCE(gm.id_sucursal, c.id_sucursal) IS NULL
      )
      AND (
          gm.id_comprobante IS NULL
          OR c.id IS NULL
          OR COALESCE(UPPER(tip.nombre), '') IN ('NOTA_CREDITO', 'NOTA_DEBITO')
      );

    SELECT
        COALESCE(SUM(gm.monto), 0),
        COALESCE(SUM(CASE
            WHEN UPPER(COALESCE(mp.nombre, 'EFECTIVO')) IN ('EFECTIVO', 'YAPE', 'PLIN')
            THEN gm.monto ELSE 0 END), 0)
    INTO v_garantias_dev, v_garantias_dev_caja
    FROM ven_garantia_movimiento gm
    INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
    LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
    LEFT JOIN gen_lista_opciones mp ON mp.id = COALESCE(
        gm.id_medio_pago,
        g.id_medio_reembolso,
        g.id_medio_pago
    )
    WHERE gm.estado = 1
      AND gm.fecha = p_fecha
      AND UPPER(tm.nombre) = 'DEVOLUCION'
      AND (
          p_id_sucursal IS NULL
          OR gm.id_sucursal = p_id_sucursal
          OR gm.id_sucursal IS NULL
      );

    RETURN json_build_object(
        'ventasContado', v_ventas_contado,
        'ventasCredito', v_ventas_credito,
        'ventasMediosCaja', v_ventas_caja,
        'cobranzas', v_cobranzas,
        'cobranzasMediosCaja', v_cobranzas_caja,
        'gastosCaja', v_gastos_caja,
        'gastosCompra', v_gastos_compra,
        'gastos', v_gastos_caja + v_gastos_compra,
        'depositos', v_depositos,
        'garantiasCobro', v_garantias_cobro,
        'garantiasCobroMediosCaja', v_garantias_cobro_caja,
        'garantiasDevolucion', v_garantias_dev,
        'garantiasDevolucionMediosCaja', v_garantias_dev_caja
    );
END;
$function$;
