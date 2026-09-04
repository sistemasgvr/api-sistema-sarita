-- ⚠️ NO EJECUTAR sin revisión — dejar aplicado a mano con apply-migration.js cuando el usuario lo confirme.
--
-- Parte B/C del diseño de 'caja histórica inmutable + devolución fechada hoy':
--
-- B. Nota de Crédito: antes fin_caja_calcular_totales excluía NC/ND por completo de
--    la clasificación de ventas ('no son una venta nueva'). Correcto en el sentido de
--    que no son 'ventasNuevas', pero el efecto real (el dinero SALE del cajón al
--    devolver) nunca se reflejaba en ningún lado: la venta original se quedaba
--    contada a valor completo para siempre, y la NC no restaba nada, en ningún día.
--    Fix: la NC ahora RESTA (ND sigue sumando, como una venta normal) en la
--    clasificación de ventasContado/ventasCredito/ventasMediosCaja/etc. — usando su
--    propio ven_pagos_de_comprobante (mismo id_medio_pago que ya se copia del
--    comprobante original al crear la NC, ver ComprobanteNotaCreditoModal.vue) y su
--    propia c.fecha (el día en que se emite la NC, normalmente hoy). Esto es la clave:
--    como la fecha de la NC es independiente de la fecha de la venta original, anular
--    una venta de hace varios días reduce la caja de HOY (cuando se emite la NC), sin
--    tocar ni reabrir la caja ya cerrada de aquel día.
--
-- C. Comunicación de baja (anular() en comprobantes.logic.ts, solo factura/nota, no
--    boleta): confirmado que ese flujo solo actualiza c.id_estado_sunat = 'BAJA' —
--    nunca c.id_estado ni c.estado — así que el comprobante se quedaba contado en
--    caja para siempre, sin ninguna forma de excluirlo. Fix: se agrega el mismo tipo
--    de exclusión que ya existe para 'ANULADO' (c.id_estado), pero sobre
--    c.id_estado_sunat = 'BAJA'. Esto excluye el comprobante de su propio día — que en
--    la práctica es aceptable porque comunicación de baja SUNAT solo es válida en una
--    ventana muy corta tras la emisión (normalmente el mismo día o pocos días), y la
--    Parte A (fin_obtener_caja_sesion_totales_congeladas) ya protege cualquier caja
--    que para entonces esté cerrada.
--
-- Sin cambio de firma en ningún caso.

-- Function: fin_caja_calcular_totales
-- Fase 3. Dos cambios de fondo:
--
--   1. La clasificación por medio de pago sale de fin_medio_pago_config, no de
--      `UPPER(mp.nombre) IN ('EFECTIVO','YAPE','PLIN')`. Ese literal estaba
--      repetido en cinco bloques de esta función: añadir un medio nuevo al
--      catálogo lo dejaba fuera del arqueo en silencio. Mismo criterio que
--      inv_signo_tipo_movimiento en F1.
--
--   2. Las ventas se miden por sus líneas de cobro (ven_pagos_de_comprobante),
--      no por el medio único de la cabecera, de modo que una venta cobrada
--      mitad en efectivo y mitad por transferencia aporta a los dos resúmenes.
--
-- Claves nuevas del JSON (las anteriores se conservan):
--   ventasEfectivo, ventasOtrosMedios, cobranzasEfectivo, gastosCajaMediosCaja.

DROP FUNCTION IF EXISTS fin_caja_calcular_totales(p_fecha date, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION fin_caja_calcular_totales(p_fecha date, p_id_sucursal integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
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
    v_gastos_caja NUMERIC(14,4) := 0;
    v_gastos_caja_medios NUMERIC(14,4) := 0;
    v_gastos_compra NUMERIC(14,4) := 0;
    v_depositos NUMERIC(14,4) := 0;
    v_garantias_cobro NUMERIC(14,4) := 0;
    v_garantias_cobro_caja NUMERIC(14,4) := 0;
    v_garantias_dev NUMERIC(14,4) := 0;
    v_garantias_dev_caja NUMERIC(14,4) := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Un movimiento sin medio de pago se sigue tratando como efectivo, que es
    -- lo que hacía el COALESCE(mp.nombre, 'EFECTIVO') anterior.
    SELECT o.id INTO v_efectivo_id
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
    WHERE UPPER(o.nombre) = 'EFECTIVO'
    LIMIT 1;

    -- Ventas, medidas por línea de cobro. Una Nota de Crédito referida a una venta
    -- anterior RESTA, en vez de excluirse: su propia c.fecha es el día en que se
    -- emite (hoy), no el día de la venta original, así que una devolución de una
    -- venta de hace días reduce la caja de HOY, no reabre ni altera la caja (ya
    -- cerrada) de aquel día. Nota de débito suma, igual que una venta normal.
    -- Antes ambas quedaban excluidas del todo, así que una NC no reducía la caja
    -- en ningún día — la venta original se quedaba contada para siempre.
    --
    -- Un comprobante dado de baja ante SUNAT (comunicación de baja, ven_estado_sunat
    -- = 'BAJA') también se excluye de su propio día: es la otra forma real de anular
    -- una factura/nota ya aceptada (no genera NC), y no existía ningún campo que lo
    -- reflejara aquí — c.id_estado nunca se setea a ANULADO en ese flujo, solo
    -- c.id_estado_sunat pasa a BAJA.
    SELECT
        COALESCE(SUM(CASE WHEN NOT x.es_credito THEN x.monto ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN x.es_credito THEN x.monto ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN x.afecta_caja THEN x.monto ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN x.es_efectivo THEN x.monto ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN NOT x.es_credito AND NOT x.es_efectivo THEN x.monto ELSE 0 END), 0)
    INTO v_ventas_contado, v_ventas_credito, v_ventas_caja, v_ventas_efectivo, v_ventas_otros
    FROM (
        SELECT
            pg.monto * CASE WHEN UPPER(COALESCE(tip.nombre, '')) = 'NOTA_CREDITO' THEN -1 ELSE 1 END AS monto,
            fin_medio_pago_flag(COALESCE(pg.id_medio_pago, v_efectivo_id), 'ES_CREDITO')  AS es_credito,
            fin_medio_pago_flag(COALESCE(pg.id_medio_pago, v_efectivo_id), 'AFECTA_CAJA') AS afecta_caja,
            fin_medio_pago_flag(COALESCE(pg.id_medio_pago, v_efectivo_id), 'ES_EFECTIVO') AS es_efectivo
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        CROSS JOIN LATERAL ven_pagos_de_comprobante(c.id) pg
        WHERE c.estado = 1
          AND c.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal OR c.id_sucursal IS NULL)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
    ) x;

    -- Cobranzas de cuentas por cobrar.
    SELECT
        COALESCE(SUM(p.monto), 0),
        COALESCE(SUM(CASE
            WHEN fin_medio_pago_flag(COALESCE(p.id_medio_pago, v_efectivo_id), 'AFECTA_CAJA')
            THEN p.monto ELSE 0 END), 0),
        COALESCE(SUM(CASE
            WHEN fin_medio_pago_flag(COALESCE(p.id_medio_pago, v_efectivo_id), 'ES_EFECTIVO')
            THEN p.monto ELSE 0 END), 0)
    INTO v_cobranzas, v_cobranzas_caja, v_cobranzas_efectivo
    FROM fin_pago p
    INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
    INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
    WHERE p.estado = 1
      AND p.fecha_pago = p_fecha
      AND UPPER(tc.nombre) = 'COBRAR'
      AND (
          p_id_sucursal IS NULL
          OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
      );

    -- Gastos de caja. `gastosCajaMediosCaja` es el subconjunto que realmente
    -- sale del arqueo: un gasto pagado por transferencia no vacía el cajón.
    SELECT
        COALESCE(SUM(g.monto), 0),
        COALESCE(SUM(CASE
            WHEN fin_medio_pago_flag(COALESCE(g.id_medio_pago, v_efectivo_id), 'AFECTA_CAJA')
            THEN g.monto ELSE 0 END), 0)
    INTO v_gastos_caja, v_gastos_caja_medios
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

    -- Cobros de garantía. El monto de una garantía (ven_garantia/ven_garantia_movimiento)
    -- nunca viaja dentro de c.total_importe del comprobante al que queda ligada — el POS
    -- la registra como efecto aparte de ven_aplicar_efectos_pos, nunca como línea de venta
    -- (ver PosVentaPanel.vue/PosAlquilerPanel.vue: "totales" solo suma líneas de producto,
    -- la garantía es un campo separado) — así que excluirla cuando gm.id_comprobante
    -- apuntaba a una boleta/factura/NV dejaba esas garantías (el caso normal: casi toda
    -- garantía se cobra junto a una venta) fuera del arqueo de caja por completo.
    SELECT
        COALESCE(SUM(gm.monto), 0),
        COALESCE(SUM(CASE
            WHEN fin_medio_pago_flag(
                COALESCE(gm.id_medio_pago, g.id_medio_pago, v_efectivo_id), 'AFECTA_CAJA')
            THEN gm.monto ELSE 0 END), 0)
    INTO v_garantias_cobro, v_garantias_cobro_caja
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
          OR COALESCE(gm.id_sucursal, c.id_sucursal) IS NULL
      );

    SELECT
        COALESCE(SUM(gm.monto), 0),
        COALESCE(SUM(CASE
            WHEN fin_medio_pago_flag(
                COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago, v_efectivo_id),
                'AFECTA_CAJA')
            THEN gm.monto ELSE 0 END), 0)
    INTO v_garantias_dev, v_garantias_dev_caja
    FROM ven_garantia_movimiento gm
    INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
    LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
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
        'ventasEfectivo', v_ventas_efectivo,
        'ventasOtrosMedios', v_ventas_otros,
        'cobranzas', v_cobranzas,
        'cobranzasMediosCaja', v_cobranzas_caja,
        'cobranzasEfectivo', v_cobranzas_efectivo,
        'gastosCaja', v_gastos_caja,
        'gastosCajaMediosCaja', v_gastos_caja_medios,
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
