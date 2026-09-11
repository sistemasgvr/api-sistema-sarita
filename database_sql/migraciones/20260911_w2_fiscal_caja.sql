-- ============================================================
-- Migracion: Wave 2 fiscal / caja
-- Fecha: 2026-09-11
--
-- 2.1 doc_anular_salida: ticket_sunat PENDIENTE ya bloquea (sin cambio).
-- 2.2 ven_crear_comprobante: reapunta CxC VSD→CPE en conversion.
-- 2.3 fin_caja_calcular_totales / fin_obtener_libro_diario:
--     sin OR id_sucursal IS NULL en ventas/garantias; libro alineado
--     (BAJA / VSD convertida / AJUSTE_NC / garantias).
-- 2.4 ven_obtener_siguiente_correlativo_resumen + ven_crear_resumen_diario:
--     pg_advisory_xact_lock(872018, yyyymmdd); Nest persiste local antes de SUNAT.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260911_w2_fiscal_caja.sql
-- ============================================================


-- ============================================================
-- database_sql/funciones/caja/fin_caja_calcular_totales.sql
-- ============================================================

-- Function: fin_caja_calcular_totales
-- Fase 3. Dos cambios de fondo:
--
--   1. La clasificaciÃ³n por medio de pago sale de fin_medio_pago_config, no de
--      `UPPER(mp.nombre) IN ('EFECTIVO','YAPE','PLIN')`. Ese literal estaba
--      repetido en cinco bloques de esta funciÃ³n: aÃ±adir un medio nuevo al
--      catÃ¡logo lo dejaba fuera del arqueo en silencio. Mismo criterio que
--      inv_signo_tipo_movimiento en F1.
--
--   2. Las ventas se miden por sus lÃ­neas de cobro (ven_pagos_de_comprobante),
--      no por el medio Ãºnico de la cabecera, de modo que una venta cobrada
--      mitad en efectivo y mitad por transferencia aporta a los dos resÃºmenes.
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
    -- lo que hacÃ­a el COALESCE(mp.nombre, 'EFECTIVO') anterior.
    SELECT o.id INTO v_efectivo_id
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
    WHERE UPPER(o.nombre) = 'EFECTIVO'
    LIMIT 1;

    -- Ventas, medidas por lÃ­nea de cobro. Una Nota de CrÃ©dito referida a una venta
    -- anterior RESTA, en vez de excluirse: su propia c.fecha es el dÃ­a en que se
    -- emite (hoy), no el dÃ­a de la venta original, asÃ­ que una devoluciÃ³n de una
    -- venta de hace dÃ­as reduce la caja de HOY, no reabre ni altera la caja (ya
    -- cerrada) de aquel dÃ­a. Nota de dÃ©bito suma, igual que una venta normal.
    -- Antes ambas quedaban excluidas del todo, asÃ­ que una NC no reducÃ­a la caja
    -- en ningÃºn dÃ­a â€” la venta original se quedaba contada para siempre.
    --
    -- Un comprobante dado de baja ante SUNAT (comunicaciÃ³n de baja, ven_estado_sunat
    -- = 'BAJA') tambiÃ©n se excluye de su propio dÃ­a: es la otra forma real de anular
    -- una factura/nota ya aceptada (no genera NC), y no existÃ­a ningÃºn campo que lo
    -- reflejara aquÃ­ â€” c.id_estado nunca se setea a ANULADO en ese flujo, solo
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

    -- Pagos de cuentas por pagar (la CxP que genera una compra a crÃ©dito).
    -- fin_registrar_pago exige caja abierta para registrarlos, pero este bloque
    -- no existÃ­a: la funciÃ³n solo sumaba los pagos con tc.nombre = 'COBRAR', asÃ­
    -- que el dinero entregado al proveedor salÃ­a del cajÃ³n sin restarse del
    -- arqueo y el efectivo esperado al cierre quedaba inflado por ese importe.
    --
    -- `pagosProveedorMediosCaja` es el subconjunto que realmente vacÃ­a el cajÃ³n,
    -- mismo criterio que gastosCajaMediosCaja: un pago por transferencia no lo toca.
    --
    -- Deliberadamente NO se suma a `gastos` ni a `gastosCompra`: gastosCompra mide
    -- el devengo de las compras tipo GASTO por su fecha de emisiÃ³n, estÃ© pagada o
    -- no, asÃ­ que sumar aquÃ­ el pago de una de esas compras a crÃ©dito contarÃ­a el
    -- mismo importe dos veces. gastosCompra tampoco entra en el arqueo (ver
    -- fin_obtener_caja_sesion / fin_cerrar_caja_sesion), de modo que restar
    -- pagosProveedorMediosCaja del efectivo esperado no duplica ninguna salida.
    --
    -- AJUSTE_NC se excluye igual que en cobranzas: una nota de crÃ©dito del
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
    -- sale del arqueo: un gasto pagado por transferencia no vacÃ­a el cajÃ³n.
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
      AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal);

    SELECT COALESCE(SUM(d.monto), 0)
    INTO v_depositos
    FROM fin_caja_deposito d
    LEFT JOIN fin_caja_sesion s ON s.id = d.id_sesion AND s.estado = 1
    WHERE d.estado = 1 AND d.fecha = p_fecha
      AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal);

    -- Cobros de garantÃ­a. El monto de una garantÃ­a (ven_garantia/ven_garantia_movimiento)
    -- nunca viaja dentro de c.total_importe del comprobante al que queda ligada â€” el POS
    -- la registra como efecto aparte de ven_aplicar_efectos_pos, nunca como lÃ­nea de venta
    -- (ver PosVentaPanel.vue/PosAlquilerPanel.vue: "totales" solo suma lÃ­neas de producto,
    -- la garantÃ­a es un campo separado) â€” asÃ­ que excluirla cuando gm.id_comprobante
    -- apuntaba a una boleta/factura/NV dejaba esas garantÃ­as (el caso normal: casi toda
    -- garantÃ­a se cobra junto a una venta) fuera del arqueo de caja por completo.
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



-- ============================================================
-- database_sql/funciones/caja/fin_obtener_libro_diario.sql
-- ============================================================

-- Function: fin_obtener_libro_diario
-- Fase 3 â€” el historial de caja se organiza en pestaÃ±as por resumen (apunte
-- 1.a.ii). El payload gana tres cosas, todas aditivas:
--
--   * `ventasPagos`  â€” una fila por lÃ­nea de cobro (ven_pagos_de_comprobante),
--     de modo que una venta cobrada mitad en efectivo y mitad por transferencia
--     aparezca en las dos pestaÃ±as. El array `ventas` (una fila por comprobante)
--     se conserva intacto porque de Ã©l viven LibroDiarioView y la exportaciÃ³n a
--     Excel.
--   * `garantias`    â€” cobros y devoluciones de garantÃ­a, que hasta ahora se
--     sumaban en los totales pero no se podÃ­an listar.
--   * `resumenes`    â€” la definiciÃ³n de las pestaÃ±as: clave, etiqueta, signo
--     respecto de la caja, total y nÃºmero de filas. El frontend dibuja las
--     pestaÃ±as a partir de esto en vez de tener la lista hardcodeada, asÃ­ que
--     aÃ±adir un resumen nuevo no obliga a tocar el Vue.
--
-- No se creÃ³ una tabla `fin_caja_resumen`: los resÃºmenes son datos derivados y
-- una tabla exigirÃ­a mantenerla sincronizada con cada venta, gasto y depÃ³sito.
--
-- P0 (20260910): `pagosProveedor` â€” pagos de cuentas por pagar (CxP de compras),
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

    -- Ventas (una fila por comprobante) â€” forma histÃ³rica, sin cambios.
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
                    || CASE WHEN d.cantidad IS NOT NULL THEN ' Ã— ' || gen_formato_cantidad(d.cantidad) ELSE '' END
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
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
        WHERE c.estado = 1
          AND c.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
          AND NOT (
              UPPER(COALESCE(tip.descripcion, '')) IN ('NV', 'VSD')
              AND EXISTS (
                  SELECT 1
                  FROM ven_comprobante conv
                  WHERE conv.id_comprobante_origen = c.id
                    AND conv.estado = 1
              )
          )
    ) t;

    -- Ventas por lÃ­nea de cobro. `grupo` es la pestaÃ±a a la que pertenece.
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
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
        CROSS JOIN LATERAL ven_pagos_de_comprobante(c.id) pg
        LEFT JOIN gen_lista_opciones mp ON mp.id = pg.id_medio_pago
        LEFT JOIN gen_lista_opciones mpe ON mpe.id = v_efectivo_id
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = pg.id_cuenta_bancaria
        WHERE c.estado = 1
          AND c.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
          AND NOT (
              UPPER(COALESCE(tip.descripcion, '')) IN ('NV', 'VSD')
              AND EXISTS (
                  SELECT 1
                  FROM ven_comprobante conv
                  WHERE conv.id_comprobante_origen = c.id
                    AND conv.estado = 1
              )
          )
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
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          AND (p_id_cliente IS NULL OR cu.id_tercero = p_id_cliente)
          -- Mismo filtro de sucursal que fin_caja_calcular_totales. Sin Ã©l, la
          -- pestaÃ±a mostraba filas de otra sucursal bajo un total que las excluÃ­a.
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )
    ) t;

    -- Pagos de cuentas por pagar (CxP de compras). P0 (20260910): el libro solo
    -- listaba los pagos de cuentas COBRAR, asÃ­ que el dinero entregado a un
    -- proveedor no aparecÃ­a en ninguna pestaÃ±a aunque hubiera salido del cajÃ³n.
    -- Va aparte de `gastos` a propÃ³sito: ahÃ­ conviven los gastos de caja con el
    -- devengo de las compras tipo GASTO, y el pago de una de esas compras a
    -- crÃ©dito aparecerÃ­a dos veces si se mezclaran.
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
          -- Clientes y proveedores viven en cli_clientes, asÃ­ que el filtro de
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
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
    ) t;

    -- DepÃ³sitos
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

    -- GarantÃ­as: cobros y devoluciones, con el mismo criterio de exclusiÃ³n que
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
          )
          -- Mismo criterio que fin_caja_calcular_totales: el cobro junto a un CPE
          -- tambiÃ©n entra (no viaja en total_importe de la venta).
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

    -- Totales del rango (suma dÃ­a a dÃ­a cuando hay filtro sucursal; si no, una pasada)
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

    -- Desglose por dÃ­a (Ãºtil en filtro mes)
    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.fecha), '[]'::json)
    INTO v_dias
    FROM (
        SELECT
            d::date AS fecha,
            fin_caja_calcular_totales(d::date, p_id_sucursal) AS totales
        FROM generate_series(p_fecha_desde, v_hasta, '1 day'::interval) d
    ) x;

    -- DefiniciÃ³n de las pestaÃ±as del historial.
    --   coleccion -> array del payload del que salen las filas
    --   filtroCampo/filtroValor -> cÃ³mo quedarse con las filas de esa pestaÃ±a
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
            ('ventas_credito',     'Ventas a crÃ©dito',     'ventasPagos', 'grupo',  'CREDITO',
             0,  (v_totales->>'ventasCredito')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'CREDITO'), 30),
            ('cobranzas',          'Cobranzas',            'cobranzas',   NULL,     NULL,
             1,  (v_totales->>'cobranzas')::NUMERIC,
             json_array_length(v_cobranzas), 40),
            ('garantias_cobradas', 'GarantÃ­as cobradas',   'garantias',   'tipo',   'COBRO',
             1,  (v_totales->>'garantiasCobro')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_garantias) e WHERE e->>'tipo' = 'COBRO'), 50),
            ('garantias_devueltas','GarantÃ­as devueltas',  'garantias',   'tipo',   'DEVOLUCION',
             -1, (v_totales->>'garantiasDevolucion')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_garantias) e WHERE e->>'tipo' = 'DEVOLUCION'), 60),
            ('pagos_proveedor',    'Pagos a proveedores',  'pagosProveedor', NULL,  NULL,
             -1, (v_totales->>'pagosProveedor')::NUMERIC,
             json_array_length(v_pagos_proveedor), 65),
            ('gastos',             'Gastos',               'gastos',      NULL,     NULL,
             -1, (v_totales->>'gastos')::NUMERIC,
             json_array_length(v_gastos), 70),
            ('depositos',          'DepÃ³sitos a banco',    'depositos',   NULL,     NULL,
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



-- ============================================================
-- database_sql/funciones/comprobantes/ven_crear_comprobante.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_crear_comprobante
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
DROP FUNCTION IF EXISTS ven_crear_comprobante(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_cliente integer, p_detalles json, p_id_tipo_operacion_sunat integer, p_id_comprobante_origen integer, p_id_motivo_nota integer, p_id_tipo_movimiento integer, p_id_tipo_venta integer, p_fecha_vencimiento date, p_tipo_cambio numeric, p_id_sucursal integer, p_id_almacen integer, p_id_condicion_pago integer, p_id_moneda integer, p_id_medio_pago integer, p_glosa character varying, p_observaciones character varying, p_periodo_contable character varying, p_operacion character varying, p_id_estado integer, p_cuotas json, p_id_usuario_auditoria integer, p_origen_pos character varying, p_efectos_pos json);
DROP FUNCTION IF EXISTS ven_crear_comprobante(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_cliente integer, p_detalles json, p_id_tipo_operacion_sunat integer, p_id_comprobante_origen integer, p_id_motivo_nota integer, p_id_tipo_movimiento integer, p_id_tipo_venta integer, p_fecha_vencimiento date, p_tipo_cambio numeric, p_id_sucursal integer, p_id_almacen integer, p_id_condicion_pago integer, p_id_moneda integer, p_id_medio_pago integer, p_glosa character varying, p_observaciones character varying, p_periodo_contable character varying, p_operacion character varying, p_id_estado integer, p_cuotas json, p_id_usuario_auditoria integer, p_origen_pos character varying, p_efectos_pos json, p_pagos json);

CREATE OR REPLACE FUNCTION ven_crear_comprobante(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying DEFAULT NULL::character varying, p_fecha date DEFAULT NULL::date, p_id_cliente integer DEFAULT NULL::integer, p_detalles json DEFAULT '[]'::json, p_id_tipo_operacion_sunat integer DEFAULT NULL::integer, p_id_comprobante_origen integer DEFAULT NULL::integer, p_id_motivo_nota integer DEFAULT NULL::integer, p_id_tipo_movimiento integer DEFAULT NULL::integer, p_id_tipo_venta integer DEFAULT NULL::integer, p_fecha_vencimiento date DEFAULT NULL::date, p_tipo_cambio numeric DEFAULT 3.5, p_id_sucursal integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_condicion_pago integer DEFAULT NULL::integer, p_id_moneda integer DEFAULT NULL::integer, p_id_medio_pago integer DEFAULT NULL::integer, p_glosa character varying DEFAULT NULL::character varying, p_observaciones character varying DEFAULT NULL::character varying, p_periodo_contable character varying DEFAULT NULL::character varying, p_operacion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_cuotas json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_origen_pos character varying DEFAULT NULL::character varying, p_efectos_pos json DEFAULT NULL::json, p_pagos json DEFAULT NULL::json)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_err_pagos TEXT;
    v_id INTEGER;
    v_id_detalle INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_detalle JSON;
    v_cuota JSON;
    v_item INTEGER;
    v_items_sin_kardex INTEGER[];
    v_id_producto INTEGER;
    v_cantidad NUMERIC(12,4);
    v_precio_unitario NUMERIC(12,6);
    v_descuento_linea NUMERIC(12,4);
    v_porcentaje_igv NUMERIC(6,4);
    v_valor_linea NUMERIC(12,4);
    v_impuesto_linea NUMERIC(12,4);
    v_importe_linea NUMERIC(12,4);
    v_codigo_afectacion VARCHAR;
    v_sub_total NUMERIC(12,4) := 0;
    v_descuento_total NUMERIC(12,4) := 0;
    v_valor_venta_total NUMERIC(12,4) := 0;
    v_igv_total NUMERIC(12,4) := 0;
    v_total_importe NUMERIC(12,4) := 0;
    v_exonerado_total NUMERIC(12,4) := 0;
    v_id_estado_sunat INTEGER;
    v_id_estado_doc INTEGER;
    v_codigo_tipo VARCHAR;
    v_numero_cuota INTEGER;
    v_id_estado_cuota INTEGER;
    v_serie_origen VARCHAR;
    v_familia_origen CHAR(1);
    v_afecta_stock BOOLEAN;
    v_requiere_stock BOOLEAN := FALSE;
    v_es_conversion_vsd BOOLEAN := FALSE;
    v_es_nota_credito BOOLEAN := FALSE;
    v_codigo_tipo_origen VARCHAR;
    v_id_almacen_origen INTEGER;
    v_id_tipo_mov_inv INTEGER;
    v_id_tipo_mov_ingreso INTEGER;
    v_nombre_tipo_venta VARCHAR;
    v_stock_disponible NUMERIC(12,4);
    v_mov_result JSON;
    v_glosa_mov VARCHAR;
    v_qty_origen NUMERIC(12,4);
    v_qty_nc_previas NUMERIC(12,4);
    v_qty_nueva NUMERIC(12,4);
    v_delta_stock NUMERIC(12,4);
    v_estado_sunat_origen VARCHAR;
    v_id_afectacion_igv INTEGER;
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
    v_es_servicio BOOLEAN;
    v_err_caja TEXT;
    v_dias_credito INTEGER := 0;
    v_numero_cuotas INTEGER := 0;
    v_dia_mes_pago INTEGER;
    v_fecha_venc_cxc DATE;
    v_fecha_primera_cuota DATE;
    v_id_tipo_cobrar INTEGER;
    v_cxc_result JSON;
    v_mes_base DATE;
    v_ultimo_dia_mes DATE;
    v_total_origen NUMERIC(12,4);
    v_id_balon INTEGER;
    v_nombre_estado_balon VARCHAR;
    v_id_estado_pendiente_envio INTEGER;
    v_id_estado_disponible INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_serie := UPPER(TRIM(p_serie));

    IF p_id_tipo_comprobante IS NULL THEN
        RETURN json_build_object('error', 'El tipo de comprobante es obligatorio', 'registro', NULL);
    END IF;

    IF v_serie IS NULL OR v_serie = '' THEN
        RETURN json_build_object('error', 'La serie es obligatoria', 'registro', NULL);
    END IF;

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del comprobante es obligatoria', 'registro', NULL);
    END IF;

    -- Si no viene sucursal, se toma del almacÃ©n (caja es por fecha + sucursal).
    IF p_id_sucursal IS NULL AND p_id_almacen IS NOT NULL THEN
        SELECT a.id_sucursal INTO p_id_sucursal
        FROM gen_almacen a
        WHERE a.id = p_id_almacen
          AND a.estado = 1
        LIMIT 1;
    END IF;

    -- OperaciÃ³n del dÃ­a: requiere caja ABIERTA (arqueo / control operativo)
    v_err_caja := fin_caja_assert_abierta(p_fecha, p_id_sucursal);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('error', v_err_caja, 'registro', NULL);
    END IF;

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF p_detalles IS NULL OR json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
        RETURN json_build_object('error', 'Debe registrar al menos un detalle', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de comprobante indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    SELECT lo.descripcion INTO v_codigo_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = p_id_tipo_comprobante;

    -- Serie: CPE SUNAT = 4 caracteres; venta sin documento (VSD) = 5 (ej. VSD01). Legacy NV01 = 4.
    IF v_codigo_tipo IN ('NV', 'VSD') THEN
        IF NOT (
            (char_length(v_serie) = 5 AND left(v_serie, 3) = 'VSD')
            OR (char_length(v_serie) = 4 AND left(v_serie, 2) = 'NV')
        ) THEN
            RETURN json_build_object(
                'error',
                'La venta sin documento debe usar serie VSD## (ej. VSD01)',
                'registro',
                NULL
            );
        END IF;
    ELSIF char_length(v_serie) <> 4 THEN
        RETURN json_build_object(
            'error',
            'La serie electrÃ³nica debe tener 4 caracteres (ej. F001, B001, FC01)',
            'registro',
            NULL
        );
    END IF;

    IF v_codigo_tipo = '01' AND left(v_serie, 1) <> 'F' THEN
        RETURN json_build_object('error', 'La factura debe usar serie que inicie con F (ej. F001)', 'registro', NULL);
    END IF;

    IF v_codigo_tipo = '03' AND left(v_serie, 1) <> 'B' THEN
        RETURN json_build_object('error', 'La boleta debe usar serie que inicie con B (ej. B001)', 'registro', NULL);
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND left(v_serie, 1) NOT IN ('F', 'B') THEN
        RETURN json_build_object(
            'error',
            'La nota de crÃ©dito/dÃ©bito debe usar serie que inicie con F o B segÃºn el comprobante origen (ej. FC01 / BC01)',
            'registro',
            NULL
        );
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NULL THEN
        RETURN json_build_object('error', 'La nota de crÃ©dito/dÃ©bito requiere el comprobante de origen', 'registro', NULL);
    END IF;

    IF p_id_comprobante_origen IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante_origen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante de origen no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    -- NC/ND solo sobre CPE ACEPTADO (alineado a FE puedeNotaCredito).
    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NOT NULL THEN
        SELECT es.nombre
        INTO v_estado_sunat_origen
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        WHERE c.id = p_id_comprobante_origen
          AND c.estado = 1;

        IF COALESCE(v_estado_sunat_origen, '') <> 'ACEPTADO' THEN
            RETURN json_build_object(
                'error',
                'Solo se puede crear nota de crÃ©dito/dÃ©bito sobre un comprobante ACEPTADO por SUNAT',
                'registro',
                NULL
            );
        END IF;
    END IF;

    v_es_nota_credito := (v_codigo_tipo = '07');

    -- ConversiÃ³n VSD/NV â†’ boleta/factura: el stock ya se descontÃ³ en el origen
    IF p_id_comprobante_origen IS NOT NULL AND v_codigo_tipo IN ('01', '03') THEN
        SELECT lo.descripcion, c.id_almacen
        INTO v_codigo_tipo_origen, v_id_almacen_origen
        FROM ven_comprobante c
        INNER JOIN gen_lista_opciones lo ON c.id_tipo_comprobante = lo.id
        WHERE c.id = p_id_comprobante_origen AND c.estado = 1;

        IF v_codigo_tipo_origen IN ('NV', 'VSD') THEN
            v_es_conversion_vsd := TRUE;

            IF EXISTS (
                SELECT 1
                FROM ven_comprobante
                WHERE id_comprobante_origen = p_id_comprobante_origen
                  AND estado = 1
            ) THEN
                RETURN json_build_object(
                    'error',
                    'Esta venta sin documento ya fue convertida a boleta/factura',
                    'registro',
                    NULL
                );
            END IF;

            -- Heredar crÃ©dito/vencimiento del VSD si el CPE no los trae (FE o legacy).
            IF p_id_condicion_pago IS NULL OR p_fecha_vencimiento IS NULL THEN
                SELECT
                    COALESCE(p_id_condicion_pago, c.id_condicion_pago),
                    COALESCE(p_fecha_vencimiento, c.fecha_vencimiento)
                INTO p_id_condicion_pago, p_fecha_vencimiento
                FROM ven_comprobante c
                WHERE c.id = p_id_comprobante_origen
                  AND c.estado = 1;
            END IF;

            IF p_id_almacen IS NULL THEN
                p_id_almacen := v_id_almacen_origen;
            ELSIF v_id_almacen_origen IS NOT NULL AND p_id_almacen <> v_id_almacen_origen THEN
                RETURN json_build_object(
                    'error',
                    'Al convertir, el almacÃ©n debe ser el mismo de la venta sin documento',
                    'registro',
                    NULL
                );
            END IF;
        END IF;
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NOT NULL THEN
        SELECT UPPER(TRIM(serie)) INTO v_serie_origen
        FROM ven_comprobante
        WHERE id = p_id_comprobante_origen AND estado = 1;

        v_familia_origen := left(COALESCE(v_serie_origen, ''), 1);
        IF v_familia_origen IN ('F', 'B') AND left(v_serie, 1) <> v_familia_origen THEN
            RETURN json_build_object(
                'error',
                format(
                    'La serie de la nota debe iniciar con %s igual que el comprobante origen (%s)',
                    v_familia_origen,
                    v_serie_origen
                ),
                'registro',
                NULL
            );
        END IF;
    END IF;

    -- No confiar en el correlativo del cliente: se asigna bajo candado de serie en la TX.
    SELECT (ven_obtener_siguiente_numero(p_id_tipo_comprobante, v_serie)->>'numero')
    INTO v_numero;

    IF v_numero IS NULL OR TRIM(v_numero) = '' THEN
        RETURN json_build_object('error', 'No se pudo asignar el correlativo del comprobante', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM ven_comprobante
        WHERE UPPER(TRIM(serie)) = v_serie AND numero = v_numero
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe un comprobante con la serie ' || v_serie || ' y nÃºmero ' || v_numero,
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_sunat
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoSunat'
      AND lo.nombre = CASE
        WHEN v_codigo_tipo IN ('NV', 'VSD') THEN 'NO_APLICA'
        ELSE 'PENDIENTE'
      END
      AND lo.estado = 1
    LIMIT 1;

    IF p_id_estado IS NOT NULL THEN
        v_id_estado_doc := p_id_estado;
    ELSE
        SELECT lo.id INTO v_id_estado_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoDocumento' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
        LIMIT 1;
    END IF;

    SELECT lo.id INTO v_id_estado_cuota
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoCuota' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_id_producto := NULLIF((v_detalle->>'id_producto')::INTEGER, 0);
        v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
        v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
        v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
        v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);

        IF v_id_producto IS NULL THEN
            RETURN json_build_object('error', 'Cada detalle debe indicar id_producto', 'registro', NULL);
        END IF;

        IF v_cantidad <= 0 THEN
            RETURN json_build_object('error', 'La cantidad de cada detalle debe ser mayor a cero', 'registro', NULL);
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM pro_producto WHERE id = v_id_producto AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error',
                'El producto ' || COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto)
                    || ' no existe o estÃ¡ inactivo',
                'registro',
                NULL
            );
        END IF;

        -- Cilindro ya comprometido / fuera de stock entregable: no venderlo de nuevo
        -- (cierra el hueco hasta que la OS lo marque; ver reserva PENDIENTE_ENVIO al final).
        v_id_balon := NULLIF((v_detalle->>'id_balon')::INTEGER, 0);
        IF v_id_balon IS NOT NULL AND NOT v_es_nota_credito THEN
            SELECT UPPER(TRIM(COALESCE(eb.nombre, '')))
            INTO v_nombre_estado_balon
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE b.id = v_id_balon AND b.estado = 1;

            IF NOT FOUND THEN
                RETURN json_build_object(
                    'error',
                    format('El cilindro #%s no existe o estÃ¡ inactivo', v_id_balon),
                    'registro', NULL
                );
            END IF;

            IF v_nombre_estado_balon IN (
                'PENDIENTE_ENVIO', 'EN_TRANSITO', 'EN_MANTENIMIENTO',
                'DADO_DE_BAJA', 'ROBO', 'PRESTADO_CLIENTE', 'EN_PODER_CLIENTE',
                'ALQUILADO', 'EN_RECARGA_EXTERNA', 'POR_RECOGER'
            ) THEN
                RETURN json_build_object(
                    'error',
                    format(
                        'El cilindro no estÃ¡ disponible para venta (estado %s)',
                        LOWER(REPLACE(v_nombre_estado_balon, '_', ' '))
                    ),
                    'registro', NULL
                );
            END IF;
        END IF;

        SELECT
            REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
            COALESCE(p.es_gas, FALSE),
            COALESCE(p.es_servicio, FALSE),
            COALESCE(p.afecta_stock, FALSE)
        INTO v_nombre_unidad, v_es_gas, v_es_servicio, v_afecta_stock
        FROM pro_producto p
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        WHERE p.id = v_id_producto;

        -- Gases (mÂ³) pueden ser decimales aunque la U.M. estÃ© mal catalogada como UNID.
        IF NOT COALESCE(v_es_gas, FALSE)
           AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
           AND v_cantidad <> TRUNC(v_cantidad)
        THEN
            RETURN json_build_object(
                'error',
                'La cantidad de ' || COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto)
                    || ' debe ser entera (unidad de medida UNID)',
                'registro',
                NULL
            );
        END IF;

        -- Servicios, alquiler (tarifa) y garantÃ­a no descuentan stock.
        IF NOT ven_producto_mueve_kardex_venta(v_id_producto, v_detalle->>'descripcion') THEN
            v_afecta_stock := FALSE;
        END IF;

        -- ND (08) no mueve stock. ConversiÃ³n VSDâ†’CPE reutiliza el descuento previo.
        IF v_afecta_stock AND NOT v_es_conversion_vsd AND v_codigo_tipo <> '08' THEN
            v_requiere_stock := TRUE;
        END IF;

        -- precio_unitario del catÃ¡logo ya incluye IGV
        v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

        v_id_afectacion_igv := NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);
        v_codigo_afectacion := NULL;

        IF v_id_afectacion_igv IS NOT NULL THEN
            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = v_id_afectacion_igv
              AND lo.estado = 1;
        END IF;

        -- Sin afectaciÃ³n: default explÃ­cito a Gravado 10 (no tratar NULL como no gravado).
        IF v_codigo_afectacion IS NULL OR TRIM(v_codigo_afectacion) = '' THEN
            SELECT lo.id, lo.descripcion
            INTO v_id_afectacion_igv, v_codigo_afectacion
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'AfectacionIgv'
              AND lo.descripcion = '10'
              AND lo.estado = 1
            LIMIT 1;

            IF v_id_afectacion_igv IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'Cada detalle debe indicar id_afectacion_igv (no se encontrÃ³ Gravado 10 en catÃ¡logo)',
                    'registro',
                    NULL
                );
            END IF;
        END IF;

        IF v_codigo_afectacion = '10' THEN
            v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
            v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
        ELSE
            v_valor_linea := v_importe_linea;
            v_impuesto_linea := 0;
            IF v_codigo_afectacion = '20' THEN
                v_exonerado_total := v_exonerado_total + v_valor_linea;
            END IF;
        END IF;

        v_descuento_total := v_descuento_total + v_descuento_linea;
        v_valor_venta_total := v_valor_venta_total + v_valor_linea;
        v_igv_total := v_igv_total + v_impuesto_linea;
        v_sub_total := v_sub_total + v_importe_linea;
        v_total_importe := v_total_importe + v_importe_linea;
    END LOOP;

    -- Cap NC (siempre, aunque no mueva kardex): qty â‰¤ origen âˆ’ NCs previas por producto.
    IF v_es_nota_credito THEN
        FOR v_id_producto, v_cantidad IN
            SELECT
                (value->>'id_producto')::INTEGER,
                SUM(COALESCE((value->>'cantidad')::NUMERIC, 0))
            FROM json_array_elements(p_detalles)
            GROUP BY 1
        LOOP
            SELECT COALESCE(SUM(d.cantidad), 0)
            INTO v_qty_origen
            FROM ven_comprobante_detalle d
            WHERE d.id_comprobante = p_id_comprobante_origen
              AND d.id_producto = v_id_producto
              AND d.estado = 1;

            SELECT COALESCE(SUM(d.cantidad), 0)
            INTO v_qty_nc_previas
            FROM ven_comprobante nc
            INNER JOIN gen_lista_opciones tc
                ON tc.id = nc.id_tipo_comprobante
               AND tc.descripcion = '07'
            INNER JOIN ven_comprobante_detalle d
                ON d.id_comprobante = nc.id
               AND d.estado = 1
               AND d.id_producto = v_id_producto
            LEFT JOIN gen_lista_opciones es ON es.id = nc.id_estado_sunat
            WHERE nc.id_comprobante_origen = p_id_comprobante_origen
              AND nc.estado = 1
              -- RECHAZADO cuenta hasta soft-delete (ven_revertir_nc_sunat_rechazada).
              AND COALESCE(es.nombre, '') NOT IN ('BAJA');

            IF v_cantidad > (v_qty_origen - v_qty_nc_previas) THEN
                RETURN json_build_object(
                    'error',
                    format(
                        'La cantidad a acreditar de %s (%s) supera lo disponible para devolver (%s). Vendida: %s, ya acreditada: %s',
                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                        v_cantidad,
                        GREATEST(v_qty_origen - v_qty_nc_previas, 0),
                        v_qty_origen,
                        v_qty_nc_previas
                    ),
                    'registro',
                    NULL
                );
            END IF;
        END LOOP;
    END IF;

    IF v_requiere_stock THEN
        IF p_id_almacen IS NULL THEN
            RETURN json_build_object(
                'error',
                'Debe indicar el almacÃ©n para descontar stock de los productos',
                'registro',
                NULL
            );
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El almacÃ©n indicado no existe o estÃ¡ inactivo', 'registro', NULL);
        END IF;

        -- NC restaura stock (INGRESO); ventas descuentan (SALIDA)
        IF v_es_nota_credito THEN
            SELECT lo.id INTO v_id_tipo_mov_inv
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'INGRESO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_mov_inv IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontrÃ³ el tipo de movimiento de inventario INGRESO',
                    'registro',
                    NULL
                );
            END IF;
        ELSE
            SELECT lo.id INTO v_id_tipo_mov_inv
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'SALIDA' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_mov_inv IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontrÃ³ el tipo de movimiento de inventario SALIDA',
                    'registro',
                    NULL
                );
            END IF;
        END IF;

        SELECT lo.nombre INTO v_nombre_tipo_venta
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_venta;

        -- Validar disponibilidad agrupando por producto (varias lÃ­neas del mismo gas).
        IF NOT v_es_nota_credito THEN
            FOR v_id_producto, v_cantidad IN
                SELECT
                    (value->>'id_producto')::INTEGER,
                    SUM(COALESCE((value->>'cantidad')::NUMERIC, 0))
                FROM json_array_elements(p_detalles)
                GROUP BY 1
            LOOP
                IF NOT ven_producto_mueve_kardex_venta(v_id_producto, NULL) THEN
                    CONTINUE;
                END IF;

                SELECT COALESCE(s.stock, 0)
                INTO v_stock_disponible
                FROM pro_stock s
                WHERE s.id_almacen = p_id_almacen
                  AND s.id_producto = v_id_producto
                  AND s.estado = 1;

                IF COALESCE(v_stock_disponible, 0) < v_cantidad THEN
                    RETURN json_build_object(
                        'error',
                        format(
                            'Stock insuficiente del producto %s en el almacÃ©n (disponible: %s, solicitado: %s)',
                            COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                            COALESCE(v_stock_disponible, 0),
                            v_cantidad
                        ),
                        'registro',
                        NULL
                    );
                END IF;
            END LOOP;
        END IF;
    END IF;

    -- Gas tambiÃ©n se valida contra pro_stock (bloque de capacidad de cilindros eliminado en F1).

    -- Ventas a crÃ©dito sin medio de pago explÃ­cito (el POS no lo pide: "excluir-credito"
    -- + "medio-requerido = !esVentaCredito", el cobro se registra despuÃ©s en CxC): sin
    -- esto, id_medio_pago queda NULL y fin_caja_calcular_totales / ven_pagos_de_comprobante
    -- lo tratan como EFECTIVO (COALESCE(..., v_efectivo_id)), contando la venta entera como
    -- "ventasContado" en vez de "ventasCredito" en la card de caja.
    IF p_id_medio_pago IS NULL AND p_id_condicion_pago IS NOT NULL THEN
        SELECT o.id INTO p_id_medio_pago
        FROM gen_condicion_pago cp
        JOIN gen_lista_opciones o ON UPPER(o.nombre) = 'CREDITO' AND o.estado = 1
        JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
        WHERE cp.id = p_id_condicion_pago
          AND (COALESCE(cp.dias_credito, 0) > 0 OR COALESCE(cp.numero_cuotas, 0) > 1)
        LIMIT 1;
    END IF;

    INSERT INTO ven_comprobante (
        id_tipo_comprobante, serie, numero,
        id_estado_sunat, id_tipo_operacion_sunat,
        id_comprobante_origen, id_motivo_nota,
        id_tipo_movimiento, id_tipo_venta,
        fecha, fecha_vencimiento, tipo_cambio,
        id_cliente, id_sucursal, id_almacen,
        id_condicion_pago, id_moneda, id_medio_pago,
        sub_total, descuento, valor_venta, igv, total_importe,
        exonerado, glosa, observaciones,
        periodo_contable, operacion, origen_pos, id_estado,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_tipo_comprobante, v_serie, v_numero,
        v_id_estado_sunat, p_id_tipo_operacion_sunat,
        p_id_comprobante_origen, p_id_motivo_nota,
        p_id_tipo_movimiento, p_id_tipo_venta,
        p_fecha, p_fecha_vencimiento, COALESCE(p_tipo_cambio, 3.5),
        p_id_cliente, p_id_sucursal, p_id_almacen,
        p_id_condicion_pago, p_id_moneda, p_id_medio_pago,
        v_sub_total, v_descuento_total, v_valor_venta_total, v_igv_total, v_total_importe,
        v_exonerado_total, p_glosa, p_observaciones,
        p_periodo_contable, p_operacion, NULLIF(TRIM(p_origen_pos), ''), v_id_estado_doc,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    v_item := 0;
    v_items_sin_kardex := ARRAY[]::INTEGER[];
    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_item := v_item + 1;

        -- LÃ­neas cuyo inventario ya mueve otro proceso (recarga de mostrador: el gas
        -- lo descuenta el movimiento del balÃ³n, con la capacidad real). El bucle de
        -- stock lee las filas ya insertadas, asÃ­ que la marca se propaga por NÂ° de Ã­tem.
        IF COALESCE((v_detalle->>'no_mueve_kardex')::BOOLEAN, FALSE) THEN
            v_items_sin_kardex := v_items_sin_kardex
                || COALESCE(NULLIF((v_detalle->>'item')::INTEGER, 0), v_item);
        END IF;

        v_id_producto := (v_detalle->>'id_producto')::INTEGER;
        v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
        v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
        v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
        v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);
        -- precio_unitario del catÃ¡logo ya incluye IGV
        v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

        v_id_afectacion_igv := NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);
        v_codigo_afectacion := NULL;

        IF v_id_afectacion_igv IS NOT NULL THEN
            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = v_id_afectacion_igv
              AND lo.estado = 1;
        END IF;

        IF v_codigo_afectacion IS NULL OR TRIM(v_codigo_afectacion) = '' THEN
            SELECT lo.id, lo.descripcion
            INTO v_id_afectacion_igv, v_codigo_afectacion
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'AfectacionIgv'
              AND lo.descripcion = '10'
              AND lo.estado = 1
            LIMIT 1;
        END IF;

        IF v_codigo_afectacion = '10' THEN
            v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
            v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
        ELSE
            v_valor_linea := v_importe_linea;
            v_impuesto_linea := 0;
        END IF;

        INSERT INTO ven_comprobante_detalle (
            id_comprobante, item, id_producto, descripcion, id_unidad_medida,
            cantidad, precio_unitario, descuento, valor_venta, porcentaje_igv,
            id_afectacion_igv, impuesto, importe,
            id_balon, capacidad_cilindro, id_estado_cilindro,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            v_id,
            COALESCE(NULLIF((v_detalle->>'item')::INTEGER, 0), v_item),
            v_id_producto,
            NULLIF(v_detalle->>'descripcion', ''),
            NULLIF((v_detalle->>'id_unidad_medida')::INTEGER, 0),
            v_cantidad,
            v_precio_unitario,
            v_descuento_linea,
            v_valor_linea,
            v_porcentaje_igv,
            v_id_afectacion_igv,
            v_impuesto_linea,
            v_importe_linea,
            NULLIF((v_detalle->>'id_balon')::INTEGER, 0),
            NULLIF((v_detalle->>'capacidad_cilindro')::NUMERIC, 0),
            NULLIF((v_detalle->>'id_estado_cilindro')::INTEGER, 0),
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END LOOP;

    IF v_es_conversion_vsd THEN
        -- Reasignar movimientos del VSD al CPE y ajustar solo diferencias de cantidad
        SELECT lo.nombre INTO v_nombre_tipo_venta
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_venta;

        v_mov_result := inv_repuntar_documento(
            p_codigo_tipo_documento_origen_actual => ven_resolver_tipo_documento_ref(v_codigo_tipo_origen, v_nombre_tipo_venta),
            p_id_documento_origen_actual          => p_id_comprobante_origen,
            p_codigo_tipo_documento_origen_nuevo  => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
            p_id_documento_origen_nuevo           => v_id,
            p_glosa                               => COALESCE(
                NULLIF(TRIM(p_glosa), ''),
                format('Salida por comprobante %s-%s (desde venta sin documento)', v_serie, v_numero)
            ),
            p_id_usuario_auditoria                => p_id_usuario_auditoria
        );

        IF v_mov_result->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov_result->>'error';
        END IF;

        FOR v_id_producto, v_qty_origen, v_qty_nueva IN
            SELECT
                COALESCE(o.id_producto, n.id_producto) AS id_producto,
                COALESCE(o.cantidad, 0) AS qty_origen,
                COALESCE(n.cantidad, 0) AS qty_nueva
            FROM (
                SELECT d.id_producto, SUM(d.cantidad) AS cantidad
                FROM ven_comprobante_detalle d
                INNER JOIN pro_producto p ON p.id = d.id_producto
                WHERE d.id_comprobante = p_id_comprobante_origen
                  AND d.estado = 1
                  AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                GROUP BY d.id_producto
            ) o
            FULL OUTER JOIN (
                SELECT
                    (value->>'id_producto')::INTEGER AS id_producto,
                    SUM(COALESCE((value->>'cantidad')::NUMERIC, 0)) AS cantidad
                FROM json_array_elements(p_detalles)
                GROUP BY (value->>'id_producto')::INTEGER
            ) n ON n.id_producto = o.id_producto
            INNER JOIN pro_producto p ON p.id = COALESCE(o.id_producto, n.id_producto)
            WHERE ven_producto_mueve_kardex_venta(p.id, NULL)
        LOOP
            v_delta_stock := v_qty_nueva - v_qty_origen;
            IF v_delta_stock = 0 THEN
                CONTINUE;
            END IF;

            IF v_delta_stock > 0 THEN
                SELECT COALESCE(s.stock, 0)
                INTO v_stock_disponible
                FROM pro_stock s
                WHERE s.id_almacen = p_id_almacen
                  AND s.id_producto = v_id_producto
                  AND s.estado = 1;

                IF COALESCE(v_stock_disponible, 0) < v_delta_stock THEN
                    RAISE EXCEPTION
                        'Stock insuficiente del producto % en el almacÃ©n (disponible: %, solicitado: %)',
                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                        COALESCE(v_stock_disponible, 0),
                        v_delta_stock;
                END IF;

                v_mov_result := inv_registrar_movimiento(
                    p_naturaleza => 'PRODUCTO',
                    p_codigo_tipo_movimiento => 'SALIDA',
                    p_fecha => p_fecha,
                    p_id_producto => v_id_producto,
                    p_cantidad => v_delta_stock,
                    p_id_almacen_origen => p_id_almacen,
                    p_codigo_tipo_documento_origen => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                    p_id_documento_origen => v_id,
                    p_glosa => format('Ajuste conversiÃ³n %s-%s (+)', v_serie, v_numero),
                    p_id_usuario_auditoria => p_id_usuario_auditoria,
                    p_forzar => TRUE
                );
            ELSE
                v_mov_result := inv_registrar_movimiento(
                    p_naturaleza => 'PRODUCTO',
                    p_codigo_tipo_movimiento => 'INGRESO',
                    p_fecha => p_fecha,
                    p_id_producto => v_id_producto,
                    p_cantidad => ABS(v_delta_stock),
                    p_id_almacen_origen => p_id_almacen,
                    p_codigo_tipo_documento_origen => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                    p_id_documento_origen => v_id,
                    p_glosa => format('Ajuste conversiÃ³n %s-%s (-)', v_serie, v_numero),
                    p_id_usuario_auditoria => p_id_usuario_auditoria,
                    p_forzar => TRUE
                );
            END IF;

            IF v_mov_result->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov_result->>'error';
            END IF;
        END LOOP;
    ELSIF v_requiere_stock THEN
        v_glosa_mov := COALESCE(
            NULLIF(TRIM(p_glosa), ''),
            CASE
                WHEN v_es_nota_credito THEN
                    format('Ingreso por nota de crÃ©dito %s-%s', v_serie, v_numero)
                ELSE
                    format('Salida por comprobante %s-%s', v_serie, v_numero)
            END
        );

        FOR v_id_detalle, v_id_producto, v_cantidad, v_detalle IN
            SELECT d.id, d.id_producto, d.cantidad, to_json(d.*)
            FROM ven_comprobante_detalle d
            WHERE d.id_comprobante = v_id AND d.estado = 1
            ORDER BY d.id
        LOOP
            SELECT ven_producto_mueve_kardex_venta(v_id_producto, v_detalle->>'descripcion')
            INTO v_afecta_stock;

            -- LÃ­neas marcadas como "no_mueve_kardex" en p_detalles: otro proceso ya
            -- descuenta ese inventario (recarga de mostrador: el movimiento del balÃ³n
            -- lleva la capacidad real). Sin esto la venta descontaba ademÃ¡s su propia
            -- cantidad y el gas salÃ­a del stock dos veces (apunte 1.c.iv.6).
            IF (v_detalle->>'item')::INTEGER = ANY(v_items_sin_kardex) THEN
                CONTINUE;
            END IF;

            -- NC de recarga: el origen no moviÃ³ kardex de producto (solo RECARGA
            -- vÃ­a balÃ³n). ven_cerrar_custodia revierte esa RECARGA; un INGRESO
            -- aquÃ­ duplicarÃ­a el gas.
            IF v_es_nota_credito
               AND p_id_comprobante_origen IS NOT NULL
               AND EXISTS (
                    SELECT 1
                    FROM ven_comprobante_detalle od
                    WHERE od.id_comprobante = p_id_comprobante_origen
                      AND od.estado = 1
                      AND od.id_producto = v_id_producto
                      AND od.id_balon IS NOT NULL
               ) THEN
                CONTINUE;
            END IF;

            IF NOT v_afecta_stock THEN
                CONTINUE;
            END IF;

            -- NC de recarga (gas+cilindro): el gas se restaura al cerrar custodia
            -- (RECARGA revert). Un INGRESO PRODUCTO aquÃ­ duplicarÃ­a stock.
            IF v_es_nota_credito
               AND p_id_comprobante_origen IS NOT NULL
               AND EXISTS (
                   SELECT 1
                   FROM ven_comprobante_detalle od
                   WHERE od.id_comprobante = p_id_comprobante_origen
                     AND od.id_producto = v_id_producto
                     AND od.id_balon IS NOT NULL
                     AND od.estado = 1
               )
            THEN
                CONTINUE;
            END IF;

            v_mov_result := inv_registrar_movimiento(
                p_naturaleza => 'PRODUCTO',
                p_codigo_tipo_movimiento => CASE WHEN v_es_nota_credito THEN 'INGRESO' ELSE 'SALIDA' END,
                p_fecha => p_fecha,
                p_id_producto => v_id_producto,
                p_cantidad => v_cantidad,
                p_id_almacen_origen => p_id_almacen,
                p_codigo_tipo_documento_origen => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                p_id_documento_origen => v_id,
                p_glosa => v_glosa_mov,
                p_id_usuario_auditoria => p_id_usuario_auditoria,
                p_id_documento_detalle => v_id_detalle
            );

            IF v_mov_result->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov_result->>'error';
            END IF;
            IF COALESCE((v_mov_result->>'creado')::boolean, TRUE) IS NOT TRUE THEN
                RAISE EXCEPTION 'No se registrÃ³ el movimiento de stock (duplicado) para el producto %', v_id_producto;
            END IF;
        END LOOP;
    END IF;

    IF p_cuotas IS NOT NULL AND json_typeof(p_cuotas) = 'array' THEN
        FOR v_cuota IN SELECT value FROM json_array_elements(p_cuotas)
        LOOP
            v_numero_cuota := COALESCE((v_cuota->>'numero_cuota')::INTEGER, 0);
            IF v_numero_cuota <= 0 THEN
                CONTINUE;
            END IF;

            INSERT INTO ven_cuotas (
                id_comprobante, numero_cuota, fecha_vencimiento, monto,
                monto_pagado, id_estado,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_numero_cuota,
                (v_cuota->>'fecha_vencimiento')::DATE,
                COALESCE((v_cuota->>'monto')::NUMERIC, 0),
                COALESCE((v_cuota->>'monto_pagado')::NUMERIC, 0),
                COALESCE(NULLIF((v_cuota->>'id_estado')::INTEGER, 0), v_id_estado_cuota),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    -- CrÃ©dito / cuotas: genera CxC vinculada al comprobante segÃºn condiciÃ³n de pago.
    -- En conversiÃ³n VSDâ†’CPE, re-apunta la CxC (y pagos) del origen al nuevo CPE
    -- para no perder crÃ©dito ya abierto ni duplicarlo.
    IF v_es_conversion_vsd AND p_id_comprobante_origen IS NOT NULL THEN
        UPDATE fin_cuenta
        SET
            id_comprobante_venta = v_id,
            numero_comprobante = v_serie || '-' || v_numero,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_comprobante_venta = p_id_comprobante_origen
          AND estado = 1;
    END IF;

    IF NOT v_es_nota_credito
       AND p_id_condicion_pago IS NOT NULL
       AND COALESCE(v_total_importe, 0) > 0
    THEN
        SELECT
            COALESCE(cp.dias_credito, 0),
            COALESCE(cp.numero_cuotas, 0),
            cp.dia_mes_pago
        INTO v_dias_credito, v_numero_cuotas, v_dia_mes_pago
        FROM gen_condicion_pago cp
        WHERE cp.id = p_id_condicion_pago
          AND cp.estado = 1;

        IF v_dias_credito > 0 OR v_numero_cuotas > 1 THEN
            IF EXISTS (
                SELECT 1
                FROM cli_clientes c
                WHERE c.id = p_id_cliente
                  AND UPPER(COALESCE(c.codigo_interno, '')) = 'CVARIOS'
            ) THEN
                RAISE EXCEPTION
                    'No se puede vender a crÃ©dito a Clientes Varios. Selecciona un cliente identificado.';
            END IF;

            IF NOT EXISTS (
                SELECT 1
                FROM fin_cuenta fc
                WHERE fc.id_comprobante_venta = v_id
                  AND fc.estado = 1
            ) THEN
                IF v_numero_cuotas > 1 THEN
                    IF v_dia_mes_pago IS NULL OR v_dia_mes_pago < 1 OR v_dia_mes_pago > 31 THEN
                        RAISE EXCEPTION
                            'La condiciÃ³n de pago en cuotas requiere dÃ­a del mes a cobrar (1 a 31).';
                    END IF;

                    -- Primera cuota: fecha vencimiento explÃ­cita, o emisiÃ³n + dÃ­as, o prÃ³ximo dÃ­a_mes_pago
                    IF p_fecha_vencimiento IS NOT NULL THEN
                        v_fecha_primera_cuota := p_fecha_vencimiento;
                    ELSIF v_dias_credito > 0 THEN
                        v_fecha_primera_cuota := COALESCE(p_fecha, CURRENT_DATE) + v_dias_credito;
                    ELSE
                        v_mes_base := date_trunc('month', COALESCE(p_fecha, CURRENT_DATE))::date;
                        v_ultimo_dia_mes := (v_mes_base + INTERVAL '1 month - 1 day')::date;
                        v_fecha_primera_cuota := LEAST(
                            (v_mes_base + ((v_dia_mes_pago - 1) * INTERVAL '1 day'))::date,
                            v_ultimo_dia_mes
                        );
                        IF v_fecha_primera_cuota < COALESCE(p_fecha, CURRENT_DATE) THEN
                            v_mes_base := (v_mes_base + INTERVAL '1 month')::date;
                            v_ultimo_dia_mes := (v_mes_base + INTERVAL '1 month - 1 day')::date;
                            v_fecha_primera_cuota := LEAST(
                                (v_mes_base + ((v_dia_mes_pago - 1) * INTERVAL '1 day'))::date,
                                v_ultimo_dia_mes
                            );
                        END IF;
                    END IF;

                    UPDATE ven_comprobante
                    SET fecha_vencimiento = v_fecha_primera_cuota
                    WHERE id = v_id
                      AND fecha_vencimiento IS NULL;

                    v_cxc_result := fin_crear_cuenta_cuotas(
                        'COBRAR',
                        p_id_cliente,
                        NULL,
                        COALESCE(p_fecha, CURRENT_DATE),
                        v_total_importe,
                        v_numero_cuotas,
                        v_fecha_primera_cuota,
                        v_dia_mes_pago,
                        format(
                            'CxC en %s cuotas (dÃ­a %s) %s-%s',
                            v_numero_cuotas,
                            v_dia_mes_pago,
                            v_serie,
                            v_numero
                        ),
                        NULL,
                        NULL,
                        NULL,
                        v_serie || '-' || v_numero,
                        p_id_usuario_auditoria,
                        v_id
                    );

                    IF v_cxc_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_cxc_result->>'error';
                    END IF;
                ELSE
                    -- CrÃ©dito simple (un solo vencimiento)
                    v_fecha_venc_cxc := COALESCE(
                        p_fecha_vencimiento,
                        (COALESCE(p_fecha, CURRENT_DATE) + v_dias_credito)
                    );

                    IF p_fecha_vencimiento IS NULL THEN
                        UPDATE ven_comprobante
                        SET fecha_vencimiento = v_fecha_venc_cxc
                        WHERE id = v_id;
                    END IF;

                    SELECT glo.id
                    INTO v_id_tipo_cobrar
                    FROM gen_lista_opciones glo
                    JOIN gen_lista gl ON gl.id = glo.id_lista
                    WHERE gl.nombre = 'TipoCuentaFinanciera'
                      AND glo.nombre = 'COBRAR'
                      AND glo.estado = 1
                    LIMIT 1;

                    IF v_id_tipo_cobrar IS NULL THEN
                        RAISE EXCEPTION
                            'No estÃ¡ configurado el tipo de cuenta COBRAR (TipoCuentaFinanciera).';
                    END IF;

                    INSERT INTO fin_cuenta (
                        id_tipo_cuenta,
                        id_tercero,
                        id_comprobante_venta,
                        numero_comprobante,
                        fecha_emision,
                        fecha_vencimiento,
                        monto_pendiente,
                        monto_abonado,
                        monto_saldo,
                        descripcion,
                        id_usuario_creacion,
                        id_usuario_modificacion
                    ) VALUES (
                        v_id_tipo_cobrar,
                        p_id_cliente,
                        v_id,
                        v_serie || '-' || v_numero,
                        COALESCE(p_fecha, CURRENT_DATE),
                        v_fecha_venc_cxc,
                        v_total_importe,
                        0,
                        v_total_importe,
                        format(
                            'CxC por venta a crÃ©dito (%s dÃ­as) %s-%s',
                            v_dias_credito,
                            v_serie,
                            v_numero
                        ),
                        p_id_usuario_auditoria,
                        p_id_usuario_auditoria
                    );
                END IF;
            END IF;
        END IF;
    END IF;

    IF v_es_nota_credito
       AND p_id_comprobante_origen IS NOT NULL
       AND COALESCE(v_total_importe, 0) > 0
    THEN
        PERFORM fin_abonar_por_nota_credito(
            p_id_comprobante_origen,
            v_id,
            v_total_importe,
            p_id_usuario_auditoria
        );

        SELECT total_importe INTO v_total_origen
        FROM ven_comprobante
        WHERE id = p_id_comprobante_origen AND estado = 1;

        IF COALESCE(v_total_importe, 0) >= COALESCE(v_total_origen, 0) - 0.05
           OR EXISTS (
               SELECT 1
               FROM ven_comprobante_detalle d
               WHERE d.id_comprobante = v_id
                 AND d.estado = 1
                 AND d.id_balon IS NOT NULL
           )
        THEN
            PERFORM ven_cerrar_custodia_comprobante(
                p_id_comprobante_origen,
                p_id_usuario_auditoria
            );
        END IF;
    END IF;

    IF p_efectos_pos IS NOT NULL AND p_efectos_pos::TEXT NOT IN ('null', '{}', '[]') THEN
        PERFORM ven_aplicar_efectos_pos(v_id, p_efectos_pos, p_id_usuario_auditoria);
    END IF;

    -- ------------------------------------------------------------
    -- Reserva logÃ­stica al vender (Approach A)
    --
    -- Entre la venta y la OS el cilindro no debe seguir DISPONIBLE (doble venta).
    -- Solo se marcan los que siguen DISPONIBLE tras efectos_pos: los de prÃ©stamo
    -- ya pasaron a PRESTADO_CLIENTE y no se tocan aquÃ­.
    -- doc_crear_desde_venta usa el mismo EstadoBalon.PENDIENTE_ENVIO y es
    -- idempotente si la reserva ya existÃ­a.
    -- ------------------------------------------------------------
    IF NOT v_es_nota_credito
       AND EXISTS (
           SELECT 1
           FROM ven_comprobante_detalle d
           WHERE d.id_comprobante = v_id
             AND d.estado = 1
             AND d.id_balon IS NOT NULL
             AND COALESCE(d.descripcion, '') !~* 'garant[iÃ­]a'
       )
    THEN
        SELECT lo.id INTO v_id_estado_pendiente_envio
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND UPPER(lo.nombre) = 'PENDIENTE_ENVIO' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_pendiente_envio IS NULL THEN
            RAISE EXCEPTION 'Falta el estado PENDIENTE_ENVIO en el catÃ¡logo EstadoBalon';
        END IF;

        SELECT lo.id INTO v_id_estado_disponible
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND UPPER(lo.nombre) = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_disponible IS NOT NULL THEN
            UPDATE bal_balon b
            SET id_estado_balon = v_id_estado_pendiente_envio,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            FROM ven_comprobante_detalle d
            WHERE d.id_comprobante = v_id
              AND d.estado = 1
              AND d.id_balon = b.id
              AND b.estado = 1
              AND COALESCE(d.descripcion, '') !~* 'garant[iÃ­]a'
              AND b.id_estado_balon = v_id_estado_disponible;
        END IF;
    END IF;

    -- Fase 3: cobro multi-medio. Va al final, cuando total_importe ya estÃ¡
    -- calculado, porque la suma de los pagos se valida contra Ã©l.
    v_err_pagos := ven_sincronizar_pagos_comprobante(v_id, p_pagos, p_id_usuario_auditoria);
    IF v_err_pagos IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err_pagos USING ERRCODE = '22023';
    END IF;

    RETURN ven_obtener_comprobante(v_id);
END;
$function$;



-- ============================================================
-- database_sql/funciones/resumen-diario/ven_obtener_siguiente_correlativo_resumen.sql
-- ============================================================

-- Function: ven_obtener_siguiente_correlativo_resumen
-- Wave2: advisory lock por fecha para evitar correlativos duplicados en carrera.
DROP FUNCTION IF EXISTS ven_obtener_siguiente_correlativo_resumen(p_fecha date);

CREATE OR REPLACE FUNCTION ven_obtener_siguiente_correlativo_resumen(p_fecha date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_ultimo INTEGER;
    v_siguiente VARCHAR(10);
    v_lock_key BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del resumen es obligatoria');
    END IF;

    -- Namespace 872018 + yyyymmdd como segundo entero del advisory lock.
    v_lock_key := to_char(p_fecha, 'YYYYMMDD')::BIGINT;
    PERFORM pg_advisory_xact_lock(872018, v_lock_key::INTEGER);

    SELECT COALESCE(MAX(NULLIF(regexp_replace(correlativo, '\D', '', 'g'), '')::INTEGER), 0)
    INTO v_ultimo
    FROM ven_resumen_diario
    WHERE estado = 1
      AND fecha = p_fecha;

    v_siguiente := LPAD((v_ultimo + 1)::TEXT, 3, '0');

    RETURN json_build_object(
        'fecha', p_fecha,
        'ultimo_correlativo', CASE WHEN v_ultimo = 0 THEN NULL ELSE LPAD(v_ultimo::TEXT, 3, '0') END,
        'correlativo', v_siguiente
    );
END;
$function$;



-- ============================================================
-- database_sql/funciones/resumen-diario/ven_crear_resumen_diario.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_crear_resumen_diario
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_crear_resumen_diario(p_fecha date, p_correlativo character varying, p_ticket_sunat character varying, p_id_estado_sunat integer, p_cdr_respuesta text, p_moneda character varying, p_cantidad_docs integer, p_total_importe numeric, p_total_igv numeric, p_total_valor_venta numeric, p_ids_comprobante json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION ven_crear_resumen_diario(p_fecha date, p_correlativo character varying, p_ticket_sunat character varying DEFAULT NULL::character varying, p_id_estado_sunat integer DEFAULT NULL::integer, p_cdr_respuesta text DEFAULT NULL::text, p_moneda character varying DEFAULT 'PEN'::character varying, p_cantidad_docs integer DEFAULT 0, p_total_importe numeric DEFAULT 0, p_total_igv numeric DEFAULT 0, p_total_valor_venta numeric DEFAULT 0, p_ids_comprobante json DEFAULT '[]'::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_correlativo VARCHAR(10);
    v_identificador VARCHAR(50);
    v_ids INTEGER[];
    v_item INTEGER := 0;
    v_id_comp INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del resumen es obligatoria', 'registro', NULL);
    END IF;

    -- Misma llave que ven_obtener_siguiente_correlativo_resumen (872018 + yyyymmdd).
    PERFORM pg_advisory_xact_lock(872018, to_char(p_fecha, 'YYYYMMDD')::INTEGER);

    v_correlativo := LPAD(regexp_replace(COALESCE(NULLIF(TRIM(p_correlativo), ''), '001'), '\D', '', 'g'), 3, '0');
    v_identificador := 'RC-' || to_char(p_fecha, 'YYYYMMDD') || '-' || v_correlativo;

    IF EXISTS (
        SELECT 1 FROM ven_resumen_diario
        WHERE estado = 1 AND fecha = p_fecha AND correlativo = v_correlativo
    ) THEN
        RETURN json_build_object(
            'error',
            'Ya existe un resumen con correlativo ' || v_correlativo || ' para esa fecha',
            'registro',
            NULL
        );
    END IF;

    SELECT COALESCE(array_agg((value::TEXT)::INTEGER), ARRAY[]::INTEGER[])
    INTO v_ids
    FROM json_array_elements_text(COALESCE(p_ids_comprobante, '[]'::JSON));

    IF COALESCE(array_length(v_ids, 1), 0) = 0 THEN
        RETURN json_build_object('error', 'El resumen debe incluir al menos un comprobante', 'registro', NULL);
    END IF;

    INSERT INTO ven_resumen_diario (
        fecha,
        correlativo,
        identificador,
        ticket_sunat,
        id_estado_sunat,
        cdr_respuesta,
        moneda,
        cantidad_docs,
        total_importe,
        total_igv,
        total_valor_venta,
        id_usuario_creacion,
        id_usuario_modificacion
    ) VALUES (
        p_fecha,
        v_correlativo,
        v_identificador,
        NULLIF(TRIM(p_ticket_sunat), ''),
        p_id_estado_sunat,
        p_cdr_respuesta,
        COALESCE(NULLIF(TRIM(p_moneda), ''), 'PEN'),
        COALESCE(p_cantidad_docs, array_length(v_ids, 1)),
        COALESCE(p_total_importe, 0),
        COALESCE(p_total_igv, 0),
        COALESCE(p_total_valor_venta, 0),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    FOREACH v_id_comp IN ARRAY v_ids LOOP
        v_item := v_item + 1;
        INSERT INTO ven_resumen_diario_detalle (
            id_resumen,
            id_comprobante,
            item,
            id_usuario_creacion,
            id_usuario_modificacion
        ) VALUES (
            v_id,
            v_id_comp,
            v_item,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END LOOP;

    RETURN ven_obtener_resumen_diario(v_id);
END;
$function$;


