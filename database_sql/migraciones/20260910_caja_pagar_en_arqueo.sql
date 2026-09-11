-- ⚠️ NO EJECUTAR sin revisión — dejar aplicado a mano con apply-migration.js cuando el usuario lo confirme.
--
-- P0 — Los pagos de cuentas por pagar (CxP de compras) no llegaban al arqueo.
--
-- Síntoma: `fin_registrar_pago` exige caja abierta para CUALQUIER pago, incluidos
-- los de tipo PAGAR (el pago a un proveedor por una compra a crédito). Pero
-- `fin_caja_calcular_totales` solo sumaba los pagos cuya cuenta es de tipo COBRAR,
-- así que el dinero entregado al proveedor salía del cajón sin aparecer en ningún
-- total: el efectivo esperado al cierre quedaba inflado por ese importe exacto y
-- el arqueo cerraba con un faltante que nadie podía explicar.
-- `fin_obtener_libro_diario` arrastraba el mismo sesgo y esos pagos no se podían
-- listar en ninguna pestaña del historial.
--
-- Qué cambia:
--   1. fin_caja_calcular_totales  — dos claves nuevas en el JSON:
--        pagosProveedor            (bruto, excluye AJUSTE_NC)
--        pagosProveedorMediosCaja  (subconjunto que sí vacía el cajón)
--      COBRAR sigue siendo ingreso; PAGAR entra como egreso.
--   2. fin_obtener_caja_sesion    — resta pagosProveedorMediosCaja de cajaEsperada.
--   3. fin_cerrar_caja_sesion     — misma resta en el monto esperado del arqueo.
--   4. fin_obtener_caja_dia       — misma resta en la rama sin sesión; de paso usa
--      gastosCajaMediosCaja (con fallback a gastosCaja) igual que las otras dos, en
--      vez de gastosCaja completo: la previsualización daba un esperado distinto al
--      que se veía en cuanto se abría la caja.
--   5. fin_obtener_libro_diario   — array `pagosProveedor` + resumen
--      'pagos_proveedor' con signo -1, y las dos claves nuevas en `totales`.
--
-- Sin doble conteo con gastosCompra: `gastosCompra` mide el devengo de las compras
-- tipo GASTO por su fecha de emisión (estén pagadas o no) y NO entra en el efectivo
-- esperado en ninguna de las tres fórmulas de arqueo, así que restar
-- pagosProveedorMediosCaja no duplica ninguna salida de caja. Por lo mismo, los
-- pagos a proveedor tampoco se suman a `gastos` (= gastosCaja + gastosCompra) ni se
-- mezclan con la colección `gastos` del libro: el pago de una compra tipo GASTO a
-- crédito aparecería dos veces.
--
-- Sesiones ya cerradas: `fin_obtener_caja_sesion` sirve la foto congelada de
-- `totales_cierre`, que para esas sesiones no tiene las claves nuevas. El COALESCE a
-- 0 las deja exactamente como estaban — esta migración no reescribe históricos.
--
-- Sin cambios de firma ni de esquema. No requiere migración de datos.

-- ---------------------------------------------------------------------------
-- 1/5
-- ---------------------------------------------------------------------------
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
--
-- P0 (20260910): los pagos de cuentas por pagar (CxP de compras) entran al JSON
-- como pagosProveedor / pagosProveedorMediosCaja. Ver el bloque correspondiente.

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
    ) x;

    -- Cobranzas de cuentas por cobrar (excluye abonos contables AJUSTE_NC:
    -- no son cobranzas reales; evitan inflar el total operativo).
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
    LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
    WHERE p.estado = 1
      AND p.fecha_pago = p_fecha
      AND UPPER(tc.nombre) = 'COBRAR'
      AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
      AND (
          p_id_sucursal IS NULL
          OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
      );

    -- Pagos de cuentas por pagar (la CxP que genera una compra a crédito).
    -- fin_registrar_pago exige caja abierta para registrarlos, pero este bloque
    -- no existía: la función solo sumaba los pagos con tc.nombre = 'COBRAR', así
    -- que el dinero entregado al proveedor salía del cajón sin restarse del
    -- arqueo y el efectivo esperado al cierre quedaba inflado por ese importe.
    --
    -- `pagosProveedorMediosCaja` es el subconjunto que realmente vacía el cajón,
    -- mismo criterio que gastosCajaMediosCaja: un pago por transferencia no lo toca.
    --
    -- Deliberadamente NO se suma a `gastos` ni a `gastosCompra`: gastosCompra mide
    -- el devengo de las compras tipo GASTO por su fecha de emisión, esté pagada o
    -- no, así que sumar aquí el pago de una de esas compras a crédito contaría el
    -- mismo importe dos veces. gastosCompra tampoco entra en el arqueo (ver
    -- fin_obtener_caja_sesion / fin_cerrar_caja_sesion), de modo que restar
    -- pagosProveedorMediosCaja del efectivo esperado no duplica ninguna salida.
    --
    -- AJUSTE_NC se excluye igual que en cobranzas: una nota de crédito del
    -- proveedor abona la CxP contablemente, no saca dinero de la caja.
    SELECT
        COALESCE(SUM(p.monto), 0),
        COALESCE(SUM(CASE
            WHEN fin_medio_pago_flag(COALESCE(p.id_medio_pago, v_efectivo_id), 'AFECTA_CAJA')
            THEN p.monto ELSE 0 END), 0)
    INTO v_pagos_proveedor, v_pagos_proveedor_caja
    FROM fin_pago p
    INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
    INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
    LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
    WHERE p.estado = 1
      AND p.fecha_pago = p_fecha
      AND UPPER(tc.nombre) = 'PAGAR'
      AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
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
        'garantiasDevolucionMediosCaja', v_garantias_dev_caja
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2/5
-- ---------------------------------------------------------------------------
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_obtener_caja_sesion
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.959Z
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
            (
                COALESCE(s.monto_inicial, 0)
                + COALESCE((v_totales->>'ventasMediosCaja')::NUMERIC, 0)
                + COALESCE((v_totales->>'cobranzasMediosCaja')::NUMERIC, 0)
                + COALESCE((v_totales->>'garantiasCobroMediosCaja')::NUMERIC, 0)
                - COALESCE((v_totales->>'depositos')::NUMERIC, 0)
                -- Fase 3: solo los gastos pagados con medios que afectan caja.
                -- Antes se restaba `gastosCaja` completo, así que un gasto pagado
                -- por transferencia bajaba el efectivo esperado sin haber salido
                -- del cajón y el arqueo salía con diferencia.
                - COALESCE((v_totales->>'gastosCajaMediosCaja')::NUMERIC,
                           (v_totales->>'gastosCaja')::NUMERIC, 0)
                -- P0 (20260910): el pago de una CxP de compra sale del cajón y no
                -- se restaba, así que el efectivo esperado salía inflado. Las
                -- sesiones cerradas antes de esta migración tienen totales_cierre
                -- congelado sin la clave: el COALESCE las deja como estaban.
                - COALESCE((v_totales->>'pagosProveedorMediosCaja')::NUMERIC, 0)
                - COALESCE((v_totales->>'garantiasDevolucionMediosCaja')::NUMERIC, 0)
            ) AS "cajaEsperada"
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

-- ---------------------------------------------------------------------------
-- 3/5
-- ---------------------------------------------------------------------------
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_cerrar_caja_sesion
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
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
    v_esperado := COALESCE(v_sesion.monto_inicial, 0)
        + COALESCE((v_totales->>'ventasMediosCaja')::NUMERIC, 0)
        + COALESCE((v_totales->>'cobranzasMediosCaja')::NUMERIC, 0)
        + COALESCE((v_totales->>'garantiasCobroMediosCaja')::NUMERIC, 0)
        - COALESCE((v_totales->>'depositos')::NUMERIC, 0)
        -- Fase 3: solo los gastos pagados con medios que afectan caja. Antes se
        -- restaba `gastosCaja` completo y un gasto pagado por transferencia
        -- generaba una diferencia de arqueo inexistente.
        - COALESCE((v_totales->>'gastosCajaMediosCaja')::NUMERIC,
                   (v_totales->>'gastosCaja')::NUMERIC, 0)
        -- P0 (20260910): pagos de CxP de compra. fin_registrar_pago exige caja
        -- abierta para registrarlos, así que ese efectivo ya salió del cajón;
        -- sin restarlo aquí el arqueo cerraba con un faltante inexistente.
        - COALESCE((v_totales->>'pagosProveedorMediosCaja')::NUMERIC, 0)
        - COALESCE((v_totales->>'garantiasDevolucionMediosCaja')::NUMERIC, 0);
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

-- ---------------------------------------------------------------------------
-- 4/5
-- ---------------------------------------------------------------------------
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_obtener_caja_dia
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.959Z
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
        -- no cambie de golpe el esperado que se venía mostrando.
        'cajaEsperada',
            COALESCE((v_totales->>'ventasMediosCaja')::NUMERIC, 0)
            + COALESCE((v_totales->>'cobranzasMediosCaja')::NUMERIC, 0)
            + COALESCE((v_totales->>'garantiasCobroMediosCaja')::NUMERIC, 0)
            - COALESCE((v_totales->>'depositos')::NUMERIC, 0)
            - COALESCE((v_totales->>'gastosCajaMediosCaja')::NUMERIC,
                       (v_totales->>'gastosCaja')::NUMERIC, 0)
            -- P0 (20260910): pagos de CxP de compra, que salen del cajón.
            - COALESCE((v_totales->>'pagosProveedorMediosCaja')::NUMERIC, 0)
            - COALESCE((v_totales->>'garantiasDevolucionMediosCaja')::NUMERIC, 0)
    ) INTO v_registro;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5/5
-- ---------------------------------------------------------------------------
-- Function: fin_obtener_libro_diario
-- Fase 3 — el historial de caja se organiza en pestañas por resumen (apunte
-- 1.a.ii). El payload gana tres cosas, todas aditivas:
--
--   * `ventasPagos`  — una fila por línea de cobro (ven_pagos_de_comprobante),
--     de modo que una venta cobrada mitad en efectivo y mitad por transferencia
--     aparezca en las dos pestañas. El array `ventas` (una fila por comprobante)
--     se conserva intacto porque de él viven LibroDiarioView y la exportación a
--     Excel.
--   * `garantias`    — cobros y devoluciones de garantía, que hasta ahora se
--     sumaban en los totales pero no se podían listar.
--   * `resumenes`    — la definición de las pestañas: clave, etiqueta, signo
--     respecto de la caja, total y número de filas. El frontend dibuja las
--     pestañas a partir de esto en vez de tener la lista hardcodeada, así que
--     añadir un resumen nuevo no obliga a tocar el Vue.
--
-- No se creó una tabla `fin_caja_resumen`: los resúmenes son datos derivados y
-- una tabla exigiría mantenerla sincronizada con cada venta, gasto y depósito.
--
-- P0 (20260910): `pagosProveedor` — pagos de cuentas por pagar (CxP de compras),
-- con su propio resumen de signo -1. Antes el libro heredaba el sesgo de
-- fin_caja_calcular_totales y solo listaba los pagos de cuentas COBRAR.

DROP FUNCTION IF EXISTS fin_obtener_libro_diario(p_fecha_desde date, p_fecha_hasta date, p_id_cliente integer, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION fin_obtener_libro_diario(p_fecha_desde date, p_fecha_hasta date DEFAULT NULL::date, p_id_cliente integer DEFAULT NULL::integer, p_id_sucursal integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_hasta DATE;
    v_efectivo_id INT;
    v_ventas JSON;
    v_ventas_pagos JSON;
    v_cobranzas JSON;
    v_pagos_proveedor JSON;
    v_gastos JSON;
    v_depositos JSON;
    v_garantias JSON;
    v_observaciones JSON;
    v_totales JSON;
    v_dias JSON;
    v_resumenes JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_desde IS NULL THEN
        RETURN json_build_object('error', 'fechaDesde es obligatoria', 'registro', NULL);
    END IF;

    v_hasta := COALESCE(p_fecha_hasta, p_fecha_desde);

    IF v_hasta < p_fecha_desde THEN
        RETURN json_build_object('error', 'fechaHasta no puede ser menor que fechaDesde', 'registro', NULL);
    END IF;

    SELECT o.id INTO v_efectivo_id
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
    WHERE UPPER(o.nombre) = 'EFECTIVO'
    LIMIT 1;

    -- Ventas (una fila por comprobante) — forma histórica, sin cambios.
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_ventas
    FROM (
        SELECT
            c.id,
            c.fecha,
            tip.nombre AS "tipoComprobante",
            c.serie,
            c.numero,
            (c.serie || '-' || c.numero) AS "serieNumero",
            c.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            mp.nombre AS "medioPago",
            CASE WHEN UPPER(COALESCE(mp.nombre, '')) = 'CREDITO' THEN true ELSE false END AS "esCredito",
            c.total_importe AS "totalImporte",
            (
                SELECT string_agg(
                    COALESCE(d.descripcion, pr.nombre)
                    || CASE WHEN d.cantidad IS NOT NULL THEN ' × ' || gen_formato_cantidad(d.cantidad) ELSE '' END
                    || CASE WHEN um.nombre IS NOT NULL THEN ' ' || um.nombre ELSE '' END,
                    '; '
                )
                FROM ven_comprobante_detalle d
                LEFT JOIN pro_producto pr ON pr.id = d.id_producto
                LEFT JOIN gen_lista_opciones um ON um.id = COALESCE(d.id_unidad_medida, pr.id_unidad_medida)
                WHERE d.id_comprobante = c.id AND d.estado = 1
            ) AS "detalleProductos"
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        LEFT JOIN gen_lista_opciones mp ON mp.id = c.id_medio_pago
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
        WHERE c.estado = 1
          AND c.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal OR c.id_sucursal IS NULL)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
    ) t;

    -- Ventas por línea de cobro. `grupo` es la pestaña a la que pertenece.
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t."idComprobante", t.item), '[]'::json)
    INTO v_ventas_pagos
    FROM (
        SELECT
            c.id AS "idComprobante",
            pg.id_pago AS "idPago",
            pg.item,
            c.fecha,
            tip.nombre AS "tipoComprobante",
            (c.serie || '-' || c.numero) AS "serieNumero",
            c.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            pg.id_medio_pago AS "idMedioPago",
            COALESCE(mp.nombre, mpe.nombre) AS "medioPago",
            pg.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            pg.numero_operacion AS "numeroOperacion",
            pg.monto,
            pg.origen,
            CASE
                WHEN fin_medio_pago_flag(COALESCE(pg.id_medio_pago, v_efectivo_id), 'ES_CREDITO')
                    THEN 'CREDITO'
                WHEN fin_medio_pago_flag(COALESCE(pg.id_medio_pago, v_efectivo_id), 'ES_EFECTIVO')
                    THEN 'EFECTIVO'
                ELSE 'OTROS'
            END AS grupo
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
        CROSS JOIN LATERAL ven_pagos_de_comprobante(c.id) pg
        LEFT JOIN gen_lista_opciones mp ON mp.id = pg.id_medio_pago
        LEFT JOIN gen_lista_opciones mpe ON mpe.id = v_efectivo_id
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = pg.id_cuenta_bancaria
        WHERE c.estado = 1
          AND c.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal OR c.id_sucursal IS NULL)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
    ) t;

    -- Cobranzas
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t."fechaPago", t.id), '[]'::json)
    INTO v_cobranzas
    FROM (
        SELECT
            p.id,
            p.fecha_pago AS "fechaPago",
            p.monto,
            p.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            p.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            p.numero_operacion AS "numeroOperacion",
            p.observacion,
            cu.id AS "idCuenta",
            COALESCE(
                NULLIF(TRIM(cu.tercero_nombre), ''),
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            cu.id_tercero AS "idCliente"
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = p.id_cuenta_bancaria
        LEFT JOIN cli_clientes cli ON cli.id = cu.id_tercero
        WHERE p.estado = 1
          AND p.fecha_pago BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tc.nombre) = 'COBRAR'
          AND (p_id_cliente IS NULL OR cu.id_tercero = p_id_cliente)
          -- Mismo filtro de sucursal que fin_caja_calcular_totales. Sin él, la
          -- pestaña mostraba filas de otra sucursal bajo un total que las excluía.
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )
    ) t;

    -- Pagos de cuentas por pagar (CxP de compras). P0 (20260910): el libro solo
    -- listaba los pagos de cuentas COBRAR, así que el dinero entregado a un
    -- proveedor no aparecía en ninguna pestaña aunque hubiera salido del cajón.
    -- Va aparte de `gastos` a propósito: ahí conviven los gastos de caja con el
    -- devengo de las compras tipo GASTO, y el pago de una de esas compras a
    -- crédito aparecería dos veces si se mezclaran.
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t."fechaPago", t.id), '[]'::json)
    INTO v_pagos_proveedor
    FROM (
        SELECT
            p.id,
            p.fecha_pago AS "fechaPago",
            p.monto,
            p.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            p.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            p.numero_operacion AS "numeroOperacion",
            p.observacion,
            cu.id AS "idCuenta",
            cu.id_tercero AS "idProveedor",
            COALESCE(
                NULLIF(TRIM(cu.tercero_nombre), ''),
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), '')
            ) AS proveedor,
            -- En un plan de cuotas la compra la referencia la cabecera, no la cuota.
            COALESCE(cu.id_comprobante_compra, pad.id_comprobante_compra) AS "idCompra",
            NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), '') AS "compraSerieNumero"
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN fin_cuenta pad ON pad.id = cu.id_cuenta_padre
        LEFT JOIN com_comprobante_compra cc
               ON cc.id = COALESCE(cu.id_comprobante_compra, pad.id_comprobante_compra)
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = p.id_cuenta_bancaria
        LEFT JOIN cli_clientes ter ON ter.id = cu.id_tercero
        WHERE p.estado = 1
          AND p.fecha_pago BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tc.nombre) = 'PAGAR'
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          -- Clientes y proveedores viven en cli_clientes, así que el filtro de
          -- tercero se aplica igual que en cobranzas.
          AND (p_id_cliente IS NULL OR cu.id_tercero = p_id_cliente)
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )
    ) t;

    -- Gastos (caja menudos + compras tipo GASTO)
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.origen, t.id), '[]'::json)
    INTO v_gastos
    FROM (
        SELECT
            g.id,
            g.fecha,
            'CAJA'::text AS origen,
            g.concepto,
            g.monto,
            g.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            g.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            g.observacion
        FROM fin_caja_gasto g
        LEFT JOIN gen_lista_opciones mp ON mp.id = g.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = g.id_cuenta_bancaria
        LEFT JOIN fin_caja_sesion sg ON sg.id = g.id_sesion AND sg.estado = 1
        WHERE g.estado = 1
          AND g.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_sucursal IS NULL OR sg.id_sucursal = p_id_sucursal)
        UNION ALL
        SELECT
            cc.id,
            cc.fecha,
            'COMPRA'::text AS origen,
            COALESCE(
                NULLIF(TRIM(cc.glosa), ''),
                NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), ''),
                'Gasto compra'
            ) AS concepto,
            cc.total_importe AS monto,
            NULL::integer AS "idMedioPago",
            NULL::varchar AS "medioPago",
            NULL::integer AS "idCuentaBancaria",
            NULL::varchar AS "cuentaBancaria",
            cc.glosa AS observacion
        FROM com_comprobante_compra cc
        LEFT JOIN gen_lista_opciones tr ON tr.id = cc.id_tipo_registro
        WHERE cc.estado = 1
          AND cc.fecha BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(COALESCE(tr.nombre, '')) = 'GASTO'
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal OR cc.id_sucursal IS NULL)
    ) t;

    -- Depósitos
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_depositos
    FROM (
        SELECT
            d.id,
            d.fecha,
            d.monto,
            d.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            d.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            d.numero_operacion AS "numeroOperacion",
            d.observacion
        FROM fin_caja_deposito d
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = d.id_cuenta_bancaria
        LEFT JOIN gen_lista_opciones mp ON mp.id = d.id_medio_pago
        LEFT JOIN fin_caja_sesion sd ON sd.id = d.id_sesion AND sd.estado = 1
        WHERE d.estado = 1
          AND d.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_sucursal IS NULL OR sd.id_sucursal = p_id_sucursal)
    ) t;

    -- Garantías: cobros y devoluciones, con el mismo criterio de exclusión que
    -- fin_caja_calcular_totales (los cobros ya incluidos en un CPE no se repiten).
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_garantias
    FROM (
        SELECT
            gm.id,
            gm.fecha,
            UPPER(tm.nombre) AS tipo,
            gm.id_garantia AS "idGarantia",
            gm.monto,
            COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago) AS "idMedioPago",
            mp.nombre AS "medioPago",
            gm.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            gm.numero_operacion AS "numeroOperacion",
            g.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            gm.observacion
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        LEFT JOIN cli_clientes cli ON cli.id = g.id_cliente
        LEFT JOIN ven_comprobante c ON c.id = gm.id_comprobante
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        LEFT JOIN gen_lista_opciones mp
               ON mp.id = COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago)
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = gm.id_cuenta_bancaria
        WHERE gm.estado = 1
          AND gm.fecha BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tm.nombre) IN ('COBRO', 'DEVOLUCION')
          AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(gm.id_sucursal, c.id_sucursal) = p_id_sucursal
              OR COALESCE(gm.id_sucursal, c.id_sucursal) IS NULL
          )
          AND (
              UPPER(tm.nombre) = 'DEVOLUCION'
              OR gm.id_comprobante IS NULL
              OR c.id IS NULL
              OR COALESCE(UPPER(tip.nombre), '') IN ('NOTA_CREDITO', 'NOTA_DEBITO')
          )
    ) t;

    -- Observaciones
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_observaciones
    FROM (
        SELECT
            o.id,
            o.fecha,
            o.texto,
            u.nombre AS usuario,
            o.fecha_creacion AS "fechaCreacion"
        FROM fin_caja_observacion o
        LEFT JOIN auth_usuarios u ON u.id = o.id_usuario_creacion
        WHERE o.estado = 1
          AND o.fecha BETWEEN p_fecha_desde AND v_hasta
    ) t;

    -- Totales del rango (suma día a día cuando hay filtro sucursal; si no, una pasada)
    SELECT json_build_object(
        'ventasContado', COALESCE(SUM((t.tot->>'ventasContado')::NUMERIC), 0),
        'ventasCredito', COALESCE(SUM((t.tot->>'ventasCredito')::NUMERIC), 0),
        'ventasMediosCaja', COALESCE(SUM((t.tot->>'ventasMediosCaja')::NUMERIC), 0),
        'ventasEfectivo', COALESCE(SUM((t.tot->>'ventasEfectivo')::NUMERIC), 0),
        'ventasOtrosMedios', COALESCE(SUM((t.tot->>'ventasOtrosMedios')::NUMERIC), 0),
        'cobranzas', COALESCE(SUM((t.tot->>'cobranzas')::NUMERIC), 0),
        'cobranzasMediosCaja', COALESCE(SUM((t.tot->>'cobranzasMediosCaja')::NUMERIC), 0),
        'cobranzasEfectivo', COALESCE(SUM((t.tot->>'cobranzasEfectivo')::NUMERIC), 0),
        'pagosProveedor', COALESCE(SUM((t.tot->>'pagosProveedor')::NUMERIC), 0),
        'pagosProveedorMediosCaja', COALESCE(SUM((t.tot->>'pagosProveedorMediosCaja')::NUMERIC), 0),
        'gastosCaja', COALESCE(SUM((t.tot->>'gastosCaja')::NUMERIC), 0),
        'gastosCajaMediosCaja', COALESCE(SUM((t.tot->>'gastosCajaMediosCaja')::NUMERIC), 0),
        'gastosCompra', COALESCE(SUM((t.tot->>'gastosCompra')::NUMERIC), 0),
        'gastos', COALESCE(SUM((t.tot->>'gastos')::NUMERIC), 0),
        'depositos', COALESCE(SUM((t.tot->>'depositos')::NUMERIC), 0),
        'garantiasCobro', COALESCE(SUM((t.tot->>'garantiasCobro')::NUMERIC), 0),
        'garantiasCobroMediosCaja', COALESCE(SUM((t.tot->>'garantiasCobroMediosCaja')::NUMERIC), 0),
        'garantiasDevolucion', COALESCE(SUM((t.tot->>'garantiasDevolucion')::NUMERIC), 0),
        'garantiasDevolucionMediosCaja', COALESCE(SUM((t.tot->>'garantiasDevolucionMediosCaja')::NUMERIC), 0)
    )
    INTO v_totales
    FROM (
        SELECT fin_caja_calcular_totales(d::date, p_id_sucursal) AS tot
        FROM generate_series(p_fecha_desde, v_hasta, '1 day'::interval) d
    ) t;

    -- Desglose por día (útil en filtro mes)
    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.fecha), '[]'::json)
    INTO v_dias
    FROM (
        SELECT
            d::date AS fecha,
            fin_caja_calcular_totales(d::date, p_id_sucursal) AS totales
        FROM generate_series(p_fecha_desde, v_hasta, '1 day'::interval) d
    ) x;

    -- Definición de las pestañas del historial.
    --   coleccion -> array del payload del que salen las filas
    --   filtroCampo/filtroValor -> cómo quedarse con las filas de esa pestaña
    --   signo -> +1 entra a caja, -1 sale, 0 no mueve caja
    SELECT json_agg(row_to_json(r) ORDER BY r.orden)
    INTO v_resumenes
    FROM (
        VALUES
            ('ventas_efectivo',    'Ventas en efectivo',   'ventasPagos', 'grupo',  'EFECTIVO',
             1,  (v_totales->>'ventasEfectivo')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'EFECTIVO'), 10),
            ('ventas_otros_medios','Ventas otros medios',  'ventasPagos', 'grupo',  'OTROS',
             1,  (v_totales->>'ventasOtrosMedios')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'OTROS'), 20),
            ('ventas_credito',     'Ventas a crédito',     'ventasPagos', 'grupo',  'CREDITO',
             0,  (v_totales->>'ventasCredito')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'CREDITO'), 30),
            ('cobranzas',          'Cobranzas',            'cobranzas',   NULL,     NULL,
             1,  (v_totales->>'cobranzas')::NUMERIC,
             json_array_length(v_cobranzas), 40),
            ('garantias_cobradas', 'Garantías cobradas',   'garantias',   'tipo',   'COBRO',
             1,  (v_totales->>'garantiasCobro')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_garantias) e WHERE e->>'tipo' = 'COBRO'), 50),
            ('garantias_devueltas','Garantías devueltas',  'garantias',   'tipo',   'DEVOLUCION',
             -1, (v_totales->>'garantiasDevolucion')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_garantias) e WHERE e->>'tipo' = 'DEVOLUCION'), 60),
            ('pagos_proveedor',    'Pagos a proveedores',  'pagosProveedor', NULL,  NULL,
             -1, (v_totales->>'pagosProveedor')::NUMERIC,
             json_array_length(v_pagos_proveedor), 65),
            ('gastos',             'Gastos',               'gastos',      NULL,     NULL,
             -1, (v_totales->>'gastos')::NUMERIC,
             json_array_length(v_gastos), 70),
            ('depositos',          'Depósitos a banco',    'depositos',   NULL,     NULL,
             -1, (v_totales->>'depositos')::NUMERIC,
             json_array_length(v_depositos), 80),
            ('observaciones',      'Observaciones',        'observaciones', NULL,   NULL,
             0,  NULL::NUMERIC,
             json_array_length(v_observaciones), 90)
    ) AS r(clave, etiqueta, coleccion, "filtroCampo", "filtroValor", signo, total, cantidad, orden);

    RETURN json_build_object(
        'registro', json_build_object(
            'fechaDesde', p_fecha_desde,
            'fechaHasta', v_hasta,
            'idCliente', p_id_cliente,
            'idSucursal', p_id_sucursal,
            'ventas', v_ventas,
            'ventasPagos', v_ventas_pagos,
            'cobranzas', v_cobranzas,
            'pagosProveedor', v_pagos_proveedor,
            'gastos', v_gastos,
            'depositos', v_depositos,
            'garantias', v_garantias,
            'observaciones', v_observaciones,
            'resumenes', v_resumenes,
            'totales', v_totales,
            'dias', v_dias
        )
    );
END;
$function$;
