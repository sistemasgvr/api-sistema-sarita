
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
          -- VSD/NV convertida a boleta/factura: el cobro ya cuenta en el CPE destino.
          -- Marca: existe otro comprobante activo con id_comprobante_origen = VSD.
          AND NOT (
              UPPER(COALESCE(tip.descripcion, '')) IN ('NV', 'VSD')
              AND EXISTS (
                  SELECT 1
                  FROM ven_comprobante conv
                  WHERE conv.id_comprobante_origen = c.id
                    AND conv.estado = 1
              )
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

-- ============================================================================

DROP FUNCTION IF EXISTS fin_obtener_caja_sesion(p_id integer);

CREATE OR REPLACE FUNCTION fin_obtener_caja_sesion(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_totales JSON;
    v_fecha DATE;
    v_id_sucursal INT;
    v_fecha_cierre TIMESTAMP;
    v_totales_congelados JSON;
    v_totales_vivo JSON;
    v_gastos JSON;
    v_depositos JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT s.fecha, s.id_sucursal, s.fecha_cierre, s.totales_cierre
    INTO v_fecha, v_id_sucursal, v_fecha_cierre, v_totales_congelados
    FROM fin_caja_sesion s WHERE s.id = p_id AND s.estado = 1;

    IF v_fecha IS NULL THEN
        RETURN json_build_object('error', 'Sesión no encontrada', 'registro', NULL);
    END IF;

    -- Sesión cerrada: sirve la foto congelada al cierre, no un recálculo en vivo — así
    -- una venta anulada días después no cambia lo que esta caja ya cerrada muestra.
    -- Sesiones cerradas antes de esta migración no tienen totales_cierre guardado; para
    -- esas se recalcula en vivo como antes (mejor esfuerzo, no hay foto que servir).
    IF v_fecha_cierre IS NOT NULL AND v_totales_congelados IS NOT NULL THEN
        v_totales := v_totales_congelados;
    ELSE
        v_totales := fin_caja_calcular_totales(v_fecha, v_id_sucursal);
    END IF;

    -- 20261007: las fotos congeladas antes del resumen por medio de pago no traen
    -- porMedio ni efectivoNeto. Se completan con el recálculo en vivo para poder
    -- revisar esos días; el resto de la foto (y monto_esperado) queda como se cerró.
    IF v_totales::JSONB->'porMedio' IS NULL THEN
        v_totales_vivo := fin_caja_calcular_totales(v_fecha, v_id_sucursal);
        v_totales := (v_totales::JSONB || jsonb_build_object(
            'porMedio', v_totales_vivo->'porMedio',
            'efectivoNeto', v_totales_vivo->'efectivoNeto'
        ))::JSON;
    END IF;

    SELECT COALESCE(json_agg(row_to_json(g) ORDER BY g.id), '[]'::JSON) INTO v_gastos
    FROM (
        SELECT
            cg.id,
            cg.fecha,
            cg.concepto,
            cg.monto,
            cg.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            cg.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cbg.alias, cbg.titular, cbg.numero_cuenta) AS "cuentaBancaria",
            cg.numero_operacion AS "numeroOperacion",
            cg.observacion
        FROM fin_caja_gasto cg
        LEFT JOIN gen_lista_opciones mp ON mp.id = cg.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cbg ON cbg.id = cg.id_cuenta_bancaria
        WHERE cg.estado = 1 AND cg.id_sesion = p_id
    ) g;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.id), '[]'::JSON) INTO v_depositos
    FROM (
        SELECT
            cd.id,
            cd.fecha,
            cd.monto,
            cd.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            cd.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            cd.numero_operacion AS "numeroOperacion",
            cd.observacion
        FROM fin_caja_deposito cd
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = cd.id_cuenta_bancaria
        LEFT JOIN gen_lista_opciones mp ON mp.id = cd.id_medio_pago
        WHERE cd.estado = 1 AND cd.id_sesion = p_id
    ) d;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            ua.nombre AS "usuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre",
            uc.nombre AS "usuarioCierre",
            v_totales AS totales,
            v_gastos AS gastos,
            v_depositos AS depositos,
            -- 20261007: el arqueo compara solo billetes: fondo + neto de la fila
            -- EFECTIVO de totales.porMedio (ventas, cobranzas y garantías cobradas en
            -- efectivo, menos gastos, pagos a proveedor, devoluciones y depósitos).
            -- Antes sumaba todo medio con AFECTA_CAJA, Yape y Plin incluidos, y el
            -- esperado nunca cuadraba con el conteo físico del cajón.
            COALESCE(s.monto_inicial, 0)
                + COALESCE((v_totales->>'efectivoNeto')::NUMERIC, 0) AS "efectivoEsperado"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        LEFT JOIN auth_usuarios ua ON ua.id = s.id_usuario_apertura
        LEFT JOIN auth_usuarios uc ON uc.id = s.id_usuario_cierre
        WHERE s.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- ============================================================================

DROP FUNCTION IF EXISTS fin_obtener_caja_dia(p_fecha date, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION fin_obtener_caja_dia(p_fecha date, p_id_sucursal integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_sesion_id INT;
    v_totales JSON;
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha es obligatoria', 'registro', NULL);
    END IF;

    SELECT s.id INTO v_sesion_id
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    LIMIT 1;

    v_totales := fin_caja_calcular_totales(p_fecha, p_id_sucursal);

    IF v_sesion_id IS NOT NULL THEN
        RETURN fin_obtener_caja_sesion(v_sesion_id);
    END IF;

    SELECT json_build_object(
        'id', NULL,
        'fecha', p_fecha,
        'idSucursal', p_id_sucursal,
        'estadoCaja', NULL,
        'montoInicial', 0,
        'totales', v_totales,
        -- Rama sin sesión: previsualización del arqueo con la misma fórmula que
        -- fin_obtener_caja_sesion / fin_cerrar_caja_sesion, para que abrir la caja
        -- no cambie de golpe el esperado que se venía mostrando. Solo efectivo
        -- (20261007): Yape/Plin van aparte en totales.porMedio.
        'efectivoEsperado', COALESCE((v_totales->>'efectivoNeto')::NUMERIC, 0)
    ) INTO v_registro;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- ============================================================================

DROP FUNCTION IF EXISTS fin_cerrar_caja_sesion(p_id integer, p_monto_efectivo_contado numeric, p_observacion character varying, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_cerrar_caja_sesion(p_id integer, p_monto_efectivo_contado numeric, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_sesion RECORD;
    v_estado_cerrada INT;
    v_totales JSON;
    v_esperado NUMERIC(14,4);
    v_diferencia NUMERIC(14,4);
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_estado_cerrada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'CERRADA'
    LIMIT 1;

    SELECT s.*, est.nombre AS estado_nombre
    INTO v_sesion
    FROM fin_caja_sesion s
    LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.id = p_id AND s.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Sesión de caja no encontrada', 'registro', NULL);
    END IF;

    IF UPPER(COALESCE(v_sesion.estado_nombre, '')) = 'CERRADA' THEN
        RETURN json_build_object('error', 'La caja ya está cerrada', 'registro', NULL);
    END IF;

    IF p_monto_efectivo_contado IS NULL OR p_monto_efectivo_contado < 0 THEN
        RETURN json_build_object('error', 'Indique el efectivo contado (arqueo)', 'registro', NULL);
    END IF;

    v_totales := fin_caja_calcular_totales(v_sesion.fecha, v_sesion.id_sucursal);
    -- 20261007: p_monto_efectivo_contado son billetes, así que se compara contra el
    -- efectivo esperado (fondo + neto de la fila EFECTIVO de porMedio). Antes el
    -- esperado sumaba todo medio con AFECTA_CAJA, Yape y Plin incluidos, y el arqueo
    -- daba un faltante igual a lo cobrado por Yape/Plin menos lo gastado por ellos.
    -- efectivoNeto ya descuenta gastos, pagos a proveedor (P0 20260910), devoluciones
    -- de garantía y depósitos pagados en efectivo.
    v_esperado := COALESCE(v_sesion.monto_inicial, 0)
        + COALESCE((v_totales->>'efectivoNeto')::NUMERIC, 0);
    v_diferencia := COALESCE(p_monto_efectivo_contado, 0) - v_esperado;

    -- Congela el desglose de totales_cierre tal como está en el instante del cierre:
    -- fin_obtener_caja_sesion lo sirve tal cual para una sesión cerrada, en vez de
    -- recalcular en vivo, así que una venta anulada días después no altera lo que
    -- esta caja ya cerrada muestra.
    UPDATE fin_caja_sesion
    SET id_estado = v_estado_cerrada,
        monto_efectivo_contado = p_monto_efectivo_contado,
        monto_esperado = v_esperado,
        diferencia = v_diferencia,
        totales_cierre = v_totales,
        observacion_cierre = NULLIF(TRIM(p_observacion), ''),
        fecha_cierre = NOW(),
        id_usuario_cierre = p_id_usuario,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre",
            v_totales AS totales
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = p_id
    ) t;

    -- Fase 3 (apunte 1.a.iii): avisar a los ADMIN del cierre y su diferencia.
    PERFORM fin_notificar_caja_admins(p_id, 'CIERRE', p_id_usuario);

    RETURN json_build_object('registro', v_registro);
END;
$function$;

