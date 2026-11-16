-- Ventas con fecha de venta y caja solo para efectivo.
--  * ven_comprobante.fecha_venta (NULL = mismo día que la emisión): la venta se hizo ese día y cuenta en su caja y en el libro diario.
--    ven_comprobante.fecha sigue siendo la FECHA DE EMISIÓN (SUNAT, correlativo, resumen diario, plazos de envío, reportes tributarios).
--  * Solo los cobros/pagos en EFECTIVO (fin_medio_pago_config.es_efectivo) exigen la caja abierta: ventas, correcciones de venta,
--    cambio de medio de cobro, cobranzas y pagos de cuentas, y compras. Con transferencia, Yape, Plin, tarjeta o crédito se registra
--    aunque la caja de ese día esté cerrada; su arqueo se recalcula (el efectivo contado no cambia) y queda el evento AJUSTE_SIN_EFECTIVO.
--  * Factura/boleta emitida desde una venta sin documento (NV/VSD): toma como fecha de venta la de esa venta y no pide caja
--    (el cobro ya entró con la venta sin documento y la caja no vuelve a contar el documento derivado).
--  * Funciones nuevas: fin_caja_refrescar_cerrada, ven_pagos_mueven_efectivo, com_refrescar_caja_compra.
--    ven_crear_comprobante recibe p_fecha_venta (último parámetro, default NULL: la API anterior sigue funcionando).
-- REQUISITO: aplicar DESPUÉS de 20261112_compras_fecha_emision.sql (usa fin_caja_recalcular_arqueo y com_comprobante_compra.fecha_emision).
-- PENDIENTE DE PUBLICAR: respaldar la base antes. Idempotente (ADD COLUMN IF NOT EXISTS, CREATE INDEX IF NOT EXISTS, DROP/CREATE OR REPLACE).
BEGIN;

ALTER TABLE public.ven_comprobante ADD COLUMN IF NOT EXISTS fecha_venta date;

COMMENT ON COLUMN public.ven_comprobante.fecha_venta IS 'Día en que se hizo la venta (caja y libro diario). NULL = mismo día que la emisión (fecha).';

CREATE INDEX IF NOT EXISTS idx_ven_comprobante_fecha_caja ON public.ven_comprobante USING btree (COALESCE(fecha_venta, fecha));

ALTER TABLE public.fin_caja_sesion_evento
DROP CONSTRAINT IF EXISTS fin_caja_sesion_evento_tipo_check;

ALTER TABLE public.fin_caja_sesion_evento
ADD CONSTRAINT fin_caja_sesion_evento_tipo_check CHECK (
  (tipo)::text = ANY (
    (ARRAY[
      'ABRIR'::character varying,
      'CERRAR'::character varying,
      'REABRIR'::character varying,
      'AJUSTE_FONDO'::character varying,
      'AJUSTE_COMPRA'::character varying,
      'AJUSTE_SIN_EFECTIVO'::character varying
    ])::TEXT[]
  )
);

-- Si la caja de una fecha y sucursal está CERRADA recalcula su arqueo y lo anota en la bitácora (operaciones sin efectivo)
DROP FUNCTION IF EXISTS public.fin_caja_refrescar_cerrada (
  p_fecha date,
  p_id_sucursal integer,
  p_monto numeric,
  p_observacion character varying,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.fin_caja_refrescar_cerrada (
  p_fecha date,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_monto numeric DEFAULT NULL::numeric,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id_sesion INTEGER;
    v_arqueo JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN NULL;
    END IF;

    -- Misma sesión que mira fin_caja_assert_abierta: la última de esa fecha y sucursal.
    SELECT s.id INTO v_id_sesion
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    ORDER BY s.id DESC
    LIMIT 1;

    IF v_id_sesion IS NULL THEN
        RETURN NULL;
    END IF;

    -- NULL si la caja sigue abierta: sus totales se calculan en vivo.
    v_arqueo := fin_caja_recalcular_arqueo(v_id_sesion, p_id_usuario);
    IF v_arqueo IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, diferencia, observacion, id_usuario)
    VALUES (
        v_id_sesion,
        'AJUSTE_SIN_EFECTIVO',
        ROUND(p_monto, 2),
        (v_arqueo->>'diferencia')::NUMERIC,
        LEFT(COALESCE(NULLIF(TRIM(p_observacion), ''), 'Operación sin efectivo registrada con la caja cerrada'), 500),
        p_id_usuario
    );

    RETURN json_build_object(
        'idSesion', v_id_sesion,
        'montoEsperado', (v_arqueo->>'montoEsperado')::NUMERIC,
        'diferencia', (v_arqueo->>'diferencia')::NUMERIC
    );
END;
$function$;

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
          AND COALESCE(c.fecha_venta, c.fecha) = p_fecha
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

-- Arma el libro diario de ventas, cobros, pagos, gastos y depósitos en un rango de fechas
DROP FUNCTION IF EXISTS public.fin_obtener_libro_diario (
  p_fecha_desde date,
  p_fecha_hasta date,
  p_id_cliente integer,
  p_id_sucursal integer
);

CREATE OR REPLACE FUNCTION public.fin_obtener_libro_diario (
  p_fecha_desde date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_id_cliente integer DEFAULT NULL::integer,
  p_id_sucursal integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
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

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_ventas
    FROM (
        SELECT
            c.id,
            -- La venta cuenta el día en que se hizo (fecha_venta); la emisión va aparte.
            COALESCE(c.fecha_venta, c.fecha) AS fecha,
            c.fecha AS "fechaEmision",
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
            ) AS "detalleProductos",
            EXISTS (
                SELECT 1
                FROM ven_comprobante ori
                JOIN gen_lista_opciones tori ON tori.id = ori.id_tipo_comprobante
                WHERE ori.id = c.id_comprobante_origen
                  AND UPPER(COALESCE(tori.descripcion, '')) IN ('NV', 'VSD')
                  AND COALESCE(tip.descripcion, '') IN ('01', '03')
            ) AS "esConversionVsd"
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        LEFT JOIN gen_lista_opciones mp ON mp.id = c.id_medio_pago
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
        WHERE c.estado = 1
          AND COALESCE(c.fecha_venta, c.fecha) BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t."idComprobante", t.item), '[]'::json)
    INTO v_ventas_pagos
    FROM (
        SELECT
            c.id AS "idComprobante",
            pg.id_pago AS "idPago",
            pg.item,
            COALESCE(c.fecha_venta, c.fecha) AS fecha,
            c.fecha AS "fechaEmision",
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
          AND COALESCE(c.fecha_venta, c.fecha) BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
          AND NOT EXISTS (
              SELECT 1
              FROM ven_comprobante ori
              JOIN gen_lista_opciones tori ON tori.id = ori.id_tipo_comprobante
              WHERE ori.id = c.id_comprobante_origen
                AND UPPER(COALESCE(tori.descripcion, '')) IN ('NV', 'VSD')
                AND COALESCE(tip.descripcion, '') IN ('01', '03')
          )
    ) t;

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
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t."fechaPago", t.clave), '[]'::json)
    INTO v_pagos_proveedor
    FROM (
        SELECT
            'P' || p.id AS clave,
            'CXP' AS origen,
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
          AND (p_id_cliente IS NULL OR cu.id_tercero = p_id_cliente)
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )

        UNION ALL

        SELECT
            'C' || cc.id,
            'CONTADO',
            cc.id,
            cc.fecha,
            cc.total_importe,
            cc.id_medio_pago,
            mp.nombre,
            cc.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta),
            cc.numero_operacion,
            cc.glosa,
            NULL::INTEGER,
            cc.id_proveedor,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), '')
            ),
            cc.id,
            NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), '')
        FROM com_comprobante_compra cc
        LEFT JOIN gen_lista_opciones mp ON mp.id = cc.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = cc.id_cuenta_bancaria
        LEFT JOIN cli_clientes ter ON ter.id = cc.id_proveedor
        WHERE cc.estado = 1
          AND cc.fecha BETWEEN p_fecha_desde AND v_hasta
          AND cc.id_medio_pago IS NOT NULL
          AND COALESCE(cc.total_importe, 0) > 0
          AND (p_id_cliente IS NULL OR cc.id_proveedor = p_id_cliente)
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
          AND NOT EXISTS (
              SELECT 1 FROM fin_cuenta fc
              WHERE fc.id_comprobante_compra = cc.id AND fc.estado = 1
          )
    ) t;

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
    ) t;

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

    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.fecha), '[]'::json)
    INTO v_dias
    FROM (
        SELECT
            d::date AS fecha,
            fin_caja_calcular_totales(d::date, p_id_sucursal) AS totales
        FROM generate_series(p_fecha_desde, v_hasta, '1 day'::interval) d
    ) x;

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

-- Registra un pago a una cuenta por cobrar o pagar y actualiza su saldo
DROP FUNCTION IF EXISTS public.fin_registrar_pago (
  p_id_cuenta integer,
  p_tipo character varying,
  p_fecha_pago date,
  p_monto numeric,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying,
  p_referencia character varying,
  p_observacion character varying,
  p_id_usuario integer,
  p_id_sucursal integer
);

CREATE OR REPLACE FUNCTION public.fin_registrar_pago (
  p_id_cuenta integer,
  p_tipo character varying,
  p_fecha_pago date DEFAULT NULL::date,
  p_monto numeric DEFAULT NULL::numeric,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_id_cuenta_bancaria integer DEFAULT NULL::integer,
  p_numero_operacion character varying DEFAULT NULL::character varying,
  p_referencia character varying DEFAULT NULL::character varying,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer,
  p_id_sucursal integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id_tipo     INT;
    v_cuenta      fin_cuenta%ROWTYPE;
    v_saldo       NUMERIC(12,2);
    v_monto       NUMERIC(12,2);
    v_nuevo_saldo NUMERIC(12,2);
    v_id_pago     INT;
    v_err_caja TEXT;
    v_id_sucursal INT;
    v_id_sucursal_cuenta INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_medio_pago IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'El medio de pago es obligatorio');
    END IF;

    v_id_sucursal_cuenta := fin_sucursal_de_cuenta(p_id_cuenta);
    IF p_id_sucursal IS NOT NULL
       AND v_id_sucursal_cuenta IS NOT NULL
       AND p_id_sucursal <> v_id_sucursal_cuenta
    THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'La sucursal del pago no coincide con la sucursal de la cuenta'
        );
    END IF;
    v_id_sucursal := COALESCE(v_id_sucursal_cuenta, p_id_sucursal);

    -- Solo el efectivo exige la caja abierta; con otros medios se recalcula el arqueo si estaba cerrada.
    IF fin_medio_pago_flag(p_id_medio_pago, 'ES_EFECTIVO') THEN
        v_err_caja := fin_caja_assert_abierta(COALESCE(p_fecha_pago, CURRENT_DATE), v_id_sucursal);
        IF v_err_caja IS NOT NULL THEN
            RETURN json_build_object('registro', NULL, 'error', v_err_caja);
        END IF;
    END IF;

    v_err_caja := fin_validar_cuenta_medio_pago(p_id_medio_pago, p_id_cuenta_bancaria);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error', v_err_caja);
    END IF;

    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera'
      AND glo.nombre = UPPER(p_tipo)
    LIMIT 1;

    SELECT * INTO v_cuenta
    FROM fin_cuenta
    WHERE id = p_id_cuenta AND estado = 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La cuenta no existe o está inactiva');
    END IF;

    IF v_id_tipo IS NOT NULL AND v_cuenta.id_tipo_cuenta <> v_id_tipo THEN
        RETURN json_build_object('registro', NULL, 'error', 'La cuenta no corresponde al tipo indicado');
    END IF;

    IF v_cuenta.numero_cuotas_total IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error',
            'Esta cuenta es un plan de cuotas: registra el pago sobre la cuota correspondiente');
    END IF;

    v_saldo := fin_redondear_monto(
        COALESCE(v_cuenta.monto_saldo, v_cuenta.monto_pendiente - COALESCE(v_cuenta.monto_abonado, 0))
    );
    v_monto := fin_redondear_monto(p_monto);

    IF v_monto IS NULL OR v_monto <= 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El monto debe ser mayor a cero');
    END IF;

    IF v_monto > v_saldo THEN
        RETURN json_build_object('registro', NULL, 'error', 'El monto excede el saldo pendiente');
    END IF;

    IF COALESCE(p_fecha_pago, CURRENT_DATE) < v_cuenta.fecha_emision THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', format(
                'La fecha del pago (%s) no puede ser anterior a la fecha de emisión de la cuenta (%s)',
                to_char(COALESCE(p_fecha_pago, CURRENT_DATE), 'DD/MM/YYYY'),
                to_char(v_cuenta.fecha_emision, 'DD/MM/YYYY')
            )
        );
    END IF;

    INSERT INTO fin_pago (
        id_cuenta, fecha_pago, monto,
        id_medio_pago, id_cuenta_bancaria, numero_operacion,
        referencia, observacion, id_sucursal, id_usuario_creacion
    ) VALUES (
        p_id_cuenta,
        COALESCE(p_fecha_pago, CURRENT_DATE),
        v_monto,
        p_id_medio_pago,
        p_id_cuenta_bancaria,
        NULLIF(TRIM(p_numero_operacion), ''),
        NULLIF(TRIM(p_referencia), ''),
        NULLIF(TRIM(p_observacion), ''),
        v_id_sucursal,
        p_id_usuario
    )
    RETURNING id INTO v_id_pago;

    v_nuevo_saldo := fin_redondear_monto(v_saldo - v_monto);

    IF v_nuevo_saldo <= 0 THEN
        UPDATE fin_cuenta
           SET monto_abonado = fin_redondear_monto(monto_pendiente),
               monto_saldo   = 0,
               id_usuario_modificacion = p_id_usuario,
               fecha_modificacion = NOW()
         WHERE id = p_id_cuenta;
        v_nuevo_saldo := 0;
    ELSE
        UPDATE fin_cuenta
           SET monto_abonado = fin_redondear_monto(COALESCE(monto_abonado, 0) + v_monto),
               monto_saldo   = v_nuevo_saldo,
               id_usuario_modificacion = p_id_usuario,
               fecha_modificacion = NOW()
         WHERE id = p_id_cuenta;
    END IF;

    IF v_cuenta.id_cuenta_padre IS NOT NULL THEN
        PERFORM fin_refrescar_cabecera_plan(v_cuenta.id_cuenta_padre);
    END IF;

    IF NOT fin_medio_pago_flag(p_id_medio_pago, 'ES_EFECTIVO') THEN
        PERFORM fin_caja_refrescar_cerrada(
            COALESCE(p_fecha_pago, CURRENT_DATE), v_id_sucursal, v_monto,
            'Pago #' || v_id_pago || ' sin efectivo registrado con la caja cerrada',
            p_id_usuario
        );
    END IF;

    RETURN json_build_object(
        'registro', json_build_object(
            'id', v_id_pago,
            'idCuenta', p_id_cuenta,
            'monto', v_monto,
            'saldoRestante', v_nuevo_saldo
        )
    );
END;
$function$;

-- Anula un pago de cuenta y repone el saldo, validando la caja
DROP FUNCTION IF EXISTS public.fin_anular_pago (
  p_id_pago integer,
  p_tipo character varying,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.fin_anular_pago (
  p_id_pago integer,
  p_tipo character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id_tipo INT;
    v_pago    fin_pago%ROWTYPE;
    v_cuenta  fin_cuenta%ROWTYPE;
    v_err_caja TEXT;
    v_id_sucursal INT;
    v_es_efectivo BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_pago FROM fin_pago WHERE id = p_id_pago AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', false, 'id', p_id_pago, 'error', 'El pago no existe o ya fue anulado');
    END IF;

    v_id_sucursal := COALESCE(v_pago.id_sucursal, fin_sucursal_de_cuenta(v_pago.id_cuenta));
    -- Sin medio, la caja lo cuenta como efectivo.
    v_es_efectivo := v_pago.id_medio_pago IS NULL OR fin_medio_pago_flag(v_pago.id_medio_pago, 'ES_EFECTIVO');
    IF v_es_efectivo THEN
        v_err_caja := fin_caja_assert_abierta(v_pago.fecha_pago, v_id_sucursal);
        IF v_err_caja IS NOT NULL THEN
            RETURN json_build_object('eliminado', false, 'id', p_id_pago, 'error', v_err_caja);
        END IF;
    END IF;

    SELECT * INTO v_cuenta FROM fin_cuenta WHERE id = v_pago.id_cuenta;

    IF p_tipo IS NOT NULL THEN
        SELECT glo.id INTO v_id_tipo
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoCuentaFinanciera'
          AND glo.nombre = UPPER(p_tipo)
        LIMIT 1;

        IF v_id_tipo IS NOT NULL AND v_cuenta.id_tipo_cuenta <> v_id_tipo THEN
            RETURN json_build_object('eliminado', false, 'id', p_id_pago, 'error', 'El pago no corresponde al tipo indicado');
        END IF;
    END IF;

    UPDATE fin_pago
       SET estado = 0,
           id_usuario_modificacion = p_id_usuario,
           fecha_modificacion = NOW()
     WHERE id = p_id_pago;

    UPDATE fin_cuenta
       SET monto_abonado = fin_redondear_monto(GREATEST(COALESCE(monto_abonado, 0) - v_pago.monto, 0)),
           monto_saldo   = fin_redondear_monto(
               GREATEST(monto_pendiente - GREATEST(COALESCE(monto_abonado, 0) - v_pago.monto, 0), 0)
           ),
           id_usuario_modificacion = p_id_usuario,
           fecha_modificacion = NOW()
     WHERE id = v_pago.id_cuenta;

    IF v_cuenta.id_cuenta_padre IS NOT NULL THEN
        PERFORM fin_refrescar_cabecera_plan(v_cuenta.id_cuenta_padre);
    END IF;

    IF NOT v_es_efectivo THEN
        PERFORM fin_caja_refrescar_cerrada(
            v_pago.fecha_pago, v_id_sucursal, v_pago.monto,
            'Pago #' || p_id_pago || ' sin efectivo anulado con la caja cerrada',
            p_id_usuario
        );
    END IF;

    RETURN json_build_object('eliminado', true, 'id', p_id_pago);
END;
$function$;

-- Devuelve el pago que una compra al contado aporta a la caja, o NULL
DROP FUNCTION IF EXISTS public.com_pago_caja_compra (p_id_comprobante integer);

CREATE OR REPLACE FUNCTION public.com_pago_caja_compra (p_id_comprobante integer) RETURNS jsonb LANGUAGE sql STABLE AS $function$
    SELECT jsonb_build_object(
        'idMedioPago', cc.id_medio_pago,
        'monto',       cc.total_importe,
        'fecha',       cc.fecha,
        'idSucursal',  cc.id_sucursal,
        'afectaCaja',  fin_medio_pago_flag(cc.id_medio_pago, 'AFECTA_CAJA'),
        'esEfectivo',  fin_medio_pago_flag(cc.id_medio_pago, 'ES_EFECTIVO')
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

-- Valida que el cambio de pago en efectivo de una compra caiga en una caja abierta
DROP FUNCTION IF EXISTS public.com_assert_caja_compra (p_antes jsonb, p_despues jsonb);

CREATE OR REPLACE FUNCTION public.com_assert_caja_compra (p_antes jsonb, p_despues jsonb) RETURNS text LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_pago JSONB;
    v_err TEXT;
BEGIN
    IF p_antes IS NOT DISTINCT FROM p_despues THEN
        RETURN NULL;
    END IF;

    FOREACH v_pago IN ARRAY ARRAY[p_antes, p_despues]
    LOOP
        -- Solo el efectivo exige la caja abierta (Yape, Plin, transferencia... no mueven efectivo).
        CONTINUE WHEN v_pago IS NULL OR NOT COALESCE((v_pago->>'esEfectivo')::BOOLEAN, FALSE);

        IF v_pago->>'idSucursal' IS NULL THEN
            RETURN 'Una compra al contado pagada en efectivo necesita sucursal: el pago sale de la caja de esa sucursal.';
        END IF;

        v_err := fin_caja_assert_abierta((v_pago->>'fecha')::DATE, (v_pago->>'idSucursal')::INTEGER);
        IF v_err IS NOT NULL THEN
            RETURN 'El pago de esta compra sale de la caja del ' || to_char((v_pago->>'fecha')::DATE, 'DD/MM/YYYY') || '. ' || v_err;
        END IF;
    END LOOP;

    RETURN NULL;
END;
$function$;

-- Recalcula el arqueo de las cajas cerradas que toca un cambio de pago de compra sin efectivo
DROP FUNCTION IF EXISTS public.com_refrescar_caja_compra (
  p_antes jsonb,
  p_despues jsonb,
  p_observacion character varying,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.com_refrescar_caja_compra (
  p_antes jsonb,
  p_despues jsonb,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS void LANGUAGE plpgsql AS $function$
DECLARE
    v_caja RECORD;
BEGIN
    IF p_antes IS NOT DISTINCT FROM p_despues THEN
        RETURN;
    END IF;

    -- Los pagos en efectivo ya pasaron por com_assert_caja_compra (caja abierta): solo quedan los demás.
    FOR v_caja IN
        SELECT DISTINCT (p->>'fecha')::DATE AS fecha, (p->>'idSucursal')::INTEGER AS id_sucursal,
               (p->>'monto')::NUMERIC AS monto
        FROM unnest(ARRAY[p_antes, p_despues]) AS p
        WHERE p IS NOT NULL
          AND p->>'fecha' IS NOT NULL
          AND NOT COALESCE((p->>'esEfectivo')::BOOLEAN, FALSE)
    LOOP
        PERFORM fin_caja_refrescar_cerrada(
            v_caja.fecha, v_caja.id_sucursal, v_caja.monto,
            COALESCE(p_observacion, 'Compra sin efectivo registrada con la caja cerrada'),
            p_id_usuario
        );
    END LOOP;
END;
$function$;

-- Crea compra
DROP FUNCTION IF EXISTS public.com_crear_compra (
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying,
  p_fecha date,
  p_id_proveedor integer,
  p_id_almacen integer,
  p_detalles jsonb,
  p_id_comprobante_referencia integer,
  p_id_doc_salida integer,
  p_id_tipo_registro integer,
  p_id_categoria_gasto integer,
  p_id_sucursal integer,
  p_id_moneda integer,
  p_id_condicion_pago integer,
  p_declarar_sunat boolean,
  p_glosa character varying,
  p_id_usuario_auditoria integer,
  p_registrar_retorno_balones boolean,
  p_fecha_llegada_almacen date,
  p_lote character varying,
  p_fecha_vencimiento_lote date,
  p_fecha_prueba_hidrostatica date,
  p_serie_guia_ingreso character varying,
  p_numero_guia_ingreso character varying,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying
);

DROP FUNCTION IF EXISTS public.com_crear_compra (
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying,
  p_fecha date,
  p_id_proveedor integer,
  p_id_almacen integer,
  p_detalles jsonb,
  p_id_comprobante_referencia integer,
  p_id_doc_salida integer,
  p_id_tipo_registro integer,
  p_id_categoria_gasto integer,
  p_id_sucursal integer,
  p_id_moneda integer,
  p_id_condicion_pago integer,
  p_declarar_sunat boolean,
  p_glosa character varying,
  p_id_usuario_auditoria integer,
  p_registrar_retorno_balones boolean,
  p_fecha_llegada_almacen date,
  p_lote character varying,
  p_fecha_vencimiento_lote date,
  p_fecha_prueba_hidrostatica date,
  p_serie_guia_ingreso character varying,
  p_numero_guia_ingreso character varying,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying,
  p_porcentaje_igv numeric
);

CREATE OR REPLACE FUNCTION public.com_crear_compra (
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying,
  p_fecha date,
  p_id_proveedor integer,
  p_id_almacen integer,
  p_detalles jsonb,
  p_id_comprobante_referencia integer DEFAULT NULL::integer,
  p_id_doc_salida integer DEFAULT NULL::integer,
  p_id_tipo_registro integer DEFAULT NULL::integer,
  p_id_categoria_gasto integer DEFAULT NULL::integer,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_id_moneda integer DEFAULT NULL::integer,
  p_id_condicion_pago integer DEFAULT NULL::integer,
  p_declarar_sunat boolean DEFAULT FALSE,
  p_glosa character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_registrar_retorno_balones boolean DEFAULT FALSE,
  p_fecha_llegada_almacen date DEFAULT NULL::date,
  p_lote character varying DEFAULT NULL::character varying,
  p_fecha_vencimiento_lote date DEFAULT NULL::date,
  p_fecha_prueba_hidrostatica date DEFAULT NULL::date,
  p_serie_guia_ingreso character varying DEFAULT NULL::character varying,
  p_numero_guia_ingreso character varying DEFAULT NULL::character varying,
  p_fecha_vencimiento_cxp date DEFAULT NULL::date,
  p_cuotas_cxp jsonb DEFAULT NULL::jsonb,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_id_cuenta_bancaria integer DEFAULT NULL::integer,
  p_numero_operacion character varying DEFAULT NULL::character varying,
  p_porcentaje_igv numeric DEFAULT 18,
  p_fecha_emision date DEFAULT NULL::date
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id_compra           INTEGER;
    v_link_planta         JSON;
    v_id_detalle          INTEGER;
    v_item                INTEGER := 0;
    v_linea               JSONB;
    v_id_producto         INTEGER;
    v_id_almacen_compra   INTEGER;
    v_id_almacen_linea    INTEGER;
    v_cantidad            NUMERIC(12,4);
    v_precio_unitario     NUMERIC(12,6);
    v_afecta_stock        BOOLEAN;
    v_es_gas              BOOLEAN;
    v_importe             NUMERIC(12,4);
    v_total_bruto         NUMERIC(12,4) := 0;
    v_porcentaje_igv      NUMERIC(5,2);
    v_tasa_igv            NUMERIC(7,4);
    v_base_imponible      NUMERIC(12,4);
    v_igv_calculado       NUMERIC(12,4);
    v_id_tipo_ingreso     INTEGER;
    v_id_tipo_doc_ref     INTEGER;
    v_result_movimiento   JSON;
    v_descripcion_linea   VARCHAR;
    v_ref_estado          INTEGER;
    v_ref_serie           VARCHAR;
    v_ref_numero          VARCHAR;
    v_glosa_final         VARCHAR;
    v_orden               RECORD;
    v_registrar_retorno   BOOLEAN;
    v_retorno_ya_registrado BOOLEAN := FALSE;
    v_id_tipo_entrada_planta INTEGER;
    v_fecha_llegada       DATE;
    v_lote                VARCHAR;
    v_fecha_venc_lote     DATE;
    v_fecha_ph            DATE;
    v_err_pago            TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha de gasto es obligatoria', 'registro', NULL);
    END IF;

    IF p_id_proveedor IS NULL THEN
        RETURN json_build_object('error', 'El proveedor es obligatorio', 'registro', NULL);
    END IF;

    IF p_fecha_emision IS NOT NULL AND p_fecha_emision > CURRENT_DATE THEN
        RETURN json_build_object('error', 'La fecha de emisión no puede ser posterior a hoy', 'registro', NULL);
    END IF;

    v_porcentaje_igv := ROUND(COALESCE(p_porcentaje_igv, 18), 2);
    IF v_porcentaje_igv < 0 OR v_porcentaje_igv > 100 THEN
        RETURN json_build_object('error', 'El porcentaje de IGV debe estar entre 0 y 100', 'registro', NULL);
    END IF;
    v_tasa_igv := v_porcentaje_igv / 100;

    IF fin_medio_pago_flag(p_id_medio_pago, 'ES_CREDITO') THEN
        RETURN json_build_object('error', 'El medio de pago de la compra no puede ser crédito: para una compra al crédito elige la condición de pago.', 'registro', NULL);
    END IF;

    v_err_pago := fin_validar_cuenta_medio_pago(p_id_medio_pago, p_id_cuenta_bancaria);
    IF v_err_pago IS NOT NULL THEN
        RETURN json_build_object('error', v_err_pago, 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_proveedor AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El proveedor indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén (por defecto) indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_detalles IS NOT NULL AND jsonb_typeof(p_detalles) IS DISTINCT FROM 'array' THEN
        RETURN json_build_object('error', 'El detalle de productos debe ser un arreglo JSON', 'registro', NULL);
    END IF;

    v_glosa_final := p_glosa;
    IF p_id_comprobante_referencia IS NOT NULL THEN
        SELECT estado, serie, numero INTO v_ref_estado, v_ref_serie, v_ref_numero
        FROM com_comprobante_compra
        WHERE id = p_id_comprobante_referencia;

        IF v_ref_estado IS NULL THEN
            RETURN json_build_object('error', 'La compra de referencia indicada no existe', 'registro', NULL);
        END IF;

        IF v_ref_estado <> 0 THEN
            RETURN json_build_object(
                'error', 'La compra de referencia debe estar anulada antes de registrar la corrección (serie ' || v_ref_serie || '-' || v_ref_numero || ' sigue activa)',
                'registro', NULL
            );
        END IF;

        IF v_glosa_final IS NULL THEN
            v_glosa_final := 'Corrige compra anulada ' || v_ref_serie || '-' || v_ref_numero;
        END IF;
    END IF;

    IF p_id_doc_salida IS NOT NULL THEN
        SELECT
            rp.id,
            rp.id_proveedor,
            rp.id_almacen,
            rp.lote,
            rp.fecha_vencimiento_lote,
            rp.fecha_prueba_hidrostatica,
            rp.fecha_llegada_almacen,
            rp.id_lote_protocolo,
            c.id AS id_compra_vinculada,
            c.serie AS serie_compra_vinculada,
            c.numero AS numero_compra_vinculada,
            est.nombre AS estado_ciclo,
            tor.nombre AS tipo_orden
        INTO v_orden
        FROM doc_salida rp
        JOIN gen_lista_opciones est ON est.id = rp.id_estado_ciclo
        JOIN gen_lista_opciones tor ON tor.id = rp.id_tipo_orden
        LEFT JOIN com_comprobante_compra c
            ON c.id = rp.id_comprobante_compra AND c.estado = 1
        WHERE rp.id = p_id_doc_salida AND rp.estado = 1
        FOR UPDATE OF rp;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La orden de recarga en planta externa indicada no existe o está inactiva', 'registro', NULL);
        END IF;

        IF v_orden.tipo_orden <> 'RECARGA_PLANTA_EXTERNA' THEN
            RETURN json_build_object('error', 'El documento indicado no es una orden de recarga en planta externa', 'registro', NULL);
        END IF;

        IF v_orden.estado_ciclo NOT IN ('GENERADA', 'EMITIDA_SUNAT') THEN
            RETURN json_build_object(
                'error', CASE
                    WHEN v_orden.estado_ciclo = 'ANULADA' THEN 'La orden de recarga indicada está anulada'
                    ELSE 'La orden de recarga aún está en borrador: genérala antes de registrar su factura'
                END,
                'registro', NULL
            );
        END IF;

        IF v_orden.id_compra_vinculada IS NOT NULL THEN
            RETURN json_build_object(
                'error', format(
                    'La orden de recarga ya tiene la compra %s vinculada; anúlala antes de registrar otra',
                    COALESCE(NULLIF(TRIM(CONCAT_WS('-', v_orden.serie_compra_vinculada, v_orden.numero_compra_vinculada)), ''), '#' || v_orden.id_compra_vinculada)
                ),
                'registro', NULL
            );
        END IF;

        IF v_orden.id_proveedor IS NOT NULL
           AND p_id_proveedor IS NOT NULL
           AND v_orden.id_proveedor <> p_id_proveedor
        THEN
            RETURN json_build_object('error', 'El proveedor de la compra no coincide con el de la orden de recarga', 'registro', NULL);
        END IF;
    END IF;

    IF p_detalles IS NOT NULL AND jsonb_array_length(p_detalles) > 0 THEN
        SELECT glo.id INTO v_id_tipo_ingreso
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoMovInv' AND glo.nombre = 'INGRESO' AND glo.estado = 1;

        SELECT glo.id INTO v_id_tipo_doc_ref
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoDocumentoRef' AND glo.nombre = 'COMPRA' AND glo.estado = 1;

        IF v_id_tipo_ingreso IS NULL OR v_id_tipo_doc_ref IS NULL THEN
            RAISE EXCEPTION 'Faltan configurar las opciones INGRESO (TipoMovInv) o COMPRA (TipoDocumentoRef) en gen_lista_opciones';
        END IF;
    END IF;

    INSERT INTO com_comprobante_compra (
        id_tipo_comprobante, serie, numero, fecha, id_proveedor,
        id_tipo_registro, id_categoria_gasto, id_sucursal, id_almacen,
        id_moneda, id_condicion_pago, sub_total, igv, total_importe,
        declarar_sunat, glosa, id_comprobante_referencia, id_doc_salida,
        id_medio_pago, id_cuenta_bancaria, numero_operacion, porcentaje_igv,
        fecha_emision, id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_tipo_comprobante, NULLIF(TRIM(p_serie), ''), NULLIF(TRIM(p_numero), ''), p_fecha, p_id_proveedor,
        p_id_tipo_registro, p_id_categoria_gasto, p_id_sucursal, p_id_almacen,
        p_id_moneda, p_id_condicion_pago, 0, 0, 0,
        p_declarar_sunat, v_glosa_final, p_id_comprobante_referencia, p_id_doc_salida,
        p_id_medio_pago, p_id_cuenta_bancaria, NULLIF(TRIM(p_numero_operacion), ''), v_porcentaje_igv,
        p_fecha_emision, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_compra;

    FOR v_linea IN SELECT * FROM jsonb_array_elements(COALESCE(p_detalles, '[]'::JSONB))
    LOOP
        v_item := v_item + 1;

        v_id_producto := (v_linea->>'id_producto')::INTEGER;
        v_cantidad := (v_linea->>'cantidad')::NUMERIC;
        v_precio_unitario := COALESCE((v_linea->>'precio_unitario')::NUMERIC, 0);
        v_id_almacen_linea := COALESCE((v_linea->>'id_almacen')::INTEGER, p_id_almacen);

        IF v_id_producto IS NULL THEN
            RAISE EXCEPTION 'La línea % no tiene id_producto', v_item;
        END IF;

        IF v_cantidad IS NULL OR v_cantidad <= 0 THEN
            RAISE EXCEPTION 'La cantidad de la línea % debe ser mayor a cero', v_item;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_linea AND estado = 1) THEN
            RAISE EXCEPTION 'El almacén id=% de la línea % no existe o está inactivo', v_id_almacen_linea, v_item;
        END IF;

        SELECT afecta_stock, COALESCE(es_gas, FALSE)
        INTO v_afecta_stock, v_es_gas
        FROM pro_producto
        WHERE id = v_id_producto AND estado = 1;

        IF v_afecta_stock IS NULL THEN
            RAISE EXCEPTION 'El producto id=% de la línea % no existe o está inactivo', v_id_producto, v_item;
        END IF;

        IF v_linea ? 'afecta_stock' AND jsonb_typeof(v_linea->'afecta_stock') <> 'null' THEN
            v_afecta_stock := COALESCE((v_linea->>'afecta_stock')::BOOLEAN, v_afecta_stock);
        END IF;

        IF p_id_doc_salida IS NOT NULL AND v_es_gas THEN
            v_afecta_stock := FALSE;
        END IF;

        v_importe := v_cantidad * v_precio_unitario;
        v_total_bruto := v_total_bruto + v_importe;

        v_descripcion_linea := v_linea->>'descripcion';
        IF v_descripcion_linea IS NULL THEN
            SELECT nombre INTO v_descripcion_linea FROM pro_producto WHERE id = v_id_producto;
        END IF;

        INSERT INTO com_comprobante_compra_detalle (
            id_comprobante, item, id_clasificacion_gasto, id_producto, descripcion,
            id_unidad_medida, id_almacen, cantidad, precio_unitario, importe,
            afecta_stock, id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            v_id_compra, v_item,
            (v_linea->>'id_clasificacion_gasto')::INTEGER,
            v_id_producto,
            v_descripcion_linea,
            (v_linea->>'id_unidad_medida')::INTEGER,
            v_id_almacen_linea,
            v_cantidad, v_precio_unitario, v_importe,
            v_afecta_stock, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_detalle;

        IF v_afecta_stock THEN
            v_result_movimiento := inv_registrar_movimiento(
                p_naturaleza                => 'PRODUCTO',
                p_codigo_tipo_movimiento    => 'INGRESO',
                p_fecha                     => p_fecha,
                p_id_producto               => v_id_producto,
                p_id_balon                  => NULL,
                p_cantidad                  => v_cantidad,
                p_id_almacen_origen         => v_id_almacen_linea,
                p_id_almacen_destino        => NULL,
                p_id_cliente                => NULL,
                p_codigo_tipo_documento_origen => 'COMPRA',
                p_id_documento_origen       => v_id_compra,
                p_id_documento_detalle      => v_id_detalle,
                p_glosa                     => 'Ingreso por compra ' || COALESCE(NULLIF(TRIM(p_serie), '') || '-' || NULLIF(TRIM(p_numero), ''), '#' || v_id_compra),
                p_id_usuario_auditoria      => p_id_usuario_auditoria
            );

            IF (v_result_movimiento->>'error') IS NOT NULL THEN
                RAISE EXCEPTION '%', v_result_movimiento->>'error';
            END IF;
        END IF;

    END LOOP;

    v_base_imponible := ROUND(v_total_bruto / (1 + v_tasa_igv), 4);
    v_igv_calculado := v_total_bruto - v_base_imponible;

    UPDATE com_comprobante_compra
    SET sub_total = v_base_imponible,
        igv = v_igv_calculado,
        total_importe = v_total_bruto,
        afecta_inventario = EXISTS (
            SELECT 1
            FROM com_comprobante_compra_detalle
            WHERE id_comprobante = v_id_compra
              AND afecta_stock = TRUE
              AND estado = 1
        )
    WHERE id = v_id_compra;

    v_id_almacen_compra := p_id_almacen;

    IF p_id_doc_salida IS NOT NULL THEN
        v_registrar_retorno := COALESCE(p_registrar_retorno_balones, FALSE);

        v_lote := COALESCE(NULLIF(TRIM(p_lote), ''), NULLIF(TRIM(v_orden.lote), ''));
        v_fecha_venc_lote := COALESCE(p_fecha_vencimiento_lote, v_orden.fecha_vencimiento_lote);
        v_fecha_ph := COALESCE(p_fecha_prueba_hidrostatica, v_orden.fecha_prueba_hidrostatica);

        SELECT lo.id INTO v_id_tipo_entrada_planta
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovInvUnificado'
          AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA'
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_entrada_planta IS NULL THEN
            RAISE EXCEPTION 'Falta configurar ENTRADA_PLANTA_EXTERNA en TipoMovInvUnificado';
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM inv_movimiento m
            JOIN doc_salida_detalle dd ON dd.id = m.id_documento_detalle
            WHERE m.estado = 1
              AND m.id_tipo_movimiento = v_id_tipo_entrada_planta
              AND m.naturaleza = 'BALON'
              AND dd.id_doc_salida = p_id_doc_salida
              AND dd.id_balon IS NOT NULL
              AND m.id_balon = dd.id_balon
        ) INTO v_retorno_ya_registrado;

        IF v_registrar_retorno AND NOT v_retorno_ya_registrado THEN
            v_fecha_llegada := COALESCE(p_fecha_llegada_almacen, p_fecha);
        ELSE
            v_registrar_retorno := FALSE;
            v_fecha_llegada := NULL;
        END IF;

        UPDATE doc_salida
        SET id_comprobante_compra   = v_id_compra,
            id_almacen_retorno      = CASE
                WHEN v_registrar_retorno THEN COALESCE(p_id_almacen, id_almacen_retorno)
                ELSE id_almacen_retorno
            END,
            serie_guia_ingreso      = COALESCE(NULLIF(TRIM(p_serie_guia_ingreso), ''), serie_guia_ingreso),
            numero_guia_ingreso     = COALESCE(NULLIF(TRIM(p_numero_guia_ingreso), ''), numero_guia_ingreso),
            fecha_llegada_almacen   = COALESCE(v_fecha_llegada, fecha_llegada_almacen),
            fecha_retorno           = COALESCE(v_fecha_llegada, fecha_retorno),
            lote                    = COALESCE(v_lote, lote),
            fecha_vencimiento_lote  = COALESCE(v_fecha_venc_lote, fecha_vencimiento_lote),
            fecha_prueba_hidrostatica = COALESCE(v_fecha_ph, fecha_prueba_hidrostatica),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion      = NOW()
        WHERE id = p_id_doc_salida AND estado = 1;

        IF v_registrar_retorno THEN
            v_link_planta := bal_finalizar_recarga_planta(
                p_id_recarga_planta        => p_id_doc_salida,
                p_id_comprobante_compra    => v_id_compra,
                p_fecha_llegada_almacen    => v_fecha_llegada,
                p_id_almacen               => COALESCE(p_id_almacen, v_id_almacen_compra),
                p_id_proveedor             => p_id_proveedor,
                p_guardar_balones_almacen  => TRUE,
                p_lote                     => v_lote,
                p_fecha_vencimiento_lote   => v_fecha_venc_lote,
                p_fecha_prueba_hidrostatica => v_fecha_ph,
                p_id_usuario_auditoria     => p_id_usuario_auditoria,
                p_id_lote_protocolo        => v_orden.id_lote_protocolo
            );

            IF v_link_planta->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_link_planta->>'error';
            END IF;
        ELSIF v_retorno_ya_registrado THEN
            PERFORM bal_sincronizar_gas_retorno_planta(p_id_doc_salida, p_id_usuario_auditoria);
        END IF;
    END IF;

    PERFORM com_generar_cxp_compra(
        v_id_compra,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    IF EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = v_id_compra AND fc.estado = 1
    ) THEN
        UPDATE com_comprobante_compra
        SET id_medio_pago = NULL, id_cuenta_bancaria = NULL, numero_operacion = NULL
        WHERE id = v_id_compra;
    ELSIF p_id_medio_pago IS NULL AND v_total_bruto > 0 THEN
        RAISE EXCEPTION 'Indica el medio de pago: una compra al contado se paga en el momento (efectivo, Yape, transferencia...).';
    END IF;

    v_err_pago := com_assert_caja_compra(NULL, com_pago_caja_compra(v_id_compra));
    IF v_err_pago IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err_pago;
    END IF;

    PERFORM com_refrescar_caja_compra(
        NULL, com_pago_caja_compra(v_id_compra),
        'Compra #' || v_id_compra || ' sin efectivo registrada con la caja cerrada',
        p_id_usuario_auditoria
    );

    RETURN com_obtener_compra(v_id_compra);
END;
$function$;

-- Anula una compra y revierte solo los movimientos que ella generó
DROP FUNCTION IF EXISTS public.com_anular_compra (
  p_id_comprobante integer,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.com_anular_compra (
  p_id_comprobante integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_detalle             RECORD;
    v_id_almacen_default  INTEGER;
    v_serie               VARCHAR;
    v_numero              VARCHAR;
    v_result_movimiento   JSON;
    v_stock_actual        NUMERIC(12,4);
    v_faltantes           TEXT := '';
    v_nombre_producto     VARCHAR;
    v_nombre_almacen      VARCHAR;
    v_orden               RECORD;
    v_hay_pagos_cxp       BOOLEAN;
    v_id_cuenta_padre     INTEGER;
    v_id_tipo_doc_compra  INTEGER;
    v_id_tipo_entrada_compra INTEGER;
    v_ids_balones_compra  INTEGER[];
    v_balon_ocupado       RECORD;
    v_err_caja            TEXT;
    v_pago_caja           JSONB;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_almacen, serie, numero
    INTO v_id_almacen_default, v_serie, v_numero
    FROM com_comprobante_compra
    WHERE id = p_id_comprobante AND estado = 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id_comprobante);
    END IF;

    v_pago_caja := com_pago_caja_compra(p_id_comprobante);
    v_err_caja := com_assert_caja_compra(v_pago_caja, NULL);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id_comprobante, 'error', v_err_caja);
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM fin_pago p
        JOIN fin_cuenta c ON c.id = p.id_cuenta
        WHERE p.estado = 1
          AND c.estado = 1
          AND (
              c.id_comprobante_compra = p_id_comprobante
              OR c.id_cuenta_padre IN (
                  SELECT fc.id
                  FROM fin_cuenta fc
                  WHERE fc.id_comprobante_compra = p_id_comprobante
                    AND fc.estado = 1
                    AND fc.id_cuenta_padre IS NULL
              )
          )
    ) INTO v_hay_pagos_cxp;

    IF v_hay_pagos_cxp THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id_comprobante,
            'error', 'No se puede anular: la cuenta por pagar vinculada tiene pagos registrados. Anule primero los pagos en Finanzas.'
        );
    END IF;

    SELECT lo.id INTO v_id_tipo_doc_compra
    FROM gen_lista_opciones lo
    JOIN gen_lista gl ON gl.id = lo.id_lista
    WHERE gl.nombre = 'TipoDocumentoRef' AND lo.nombre = 'COMPRA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_entrada_compra
    FROM gen_lista_opciones lo
    JOIN gen_lista gl ON gl.id = lo.id_lista
    WHERE gl.nombre = 'TipoMovInvUnificado' AND lo.nombre = 'ENTRADA_COMPRA' AND lo.estado = 1
    LIMIT 1;

    SELECT COALESCE(array_agg(DISTINCT m.id_balon) FILTER (WHERE m.id_balon IS NOT NULL), ARRAY[]::INTEGER[])
    INTO v_ids_balones_compra
    FROM inv_movimiento m
    WHERE m.estado = 1
      AND m.naturaleza = 'BALON'
      AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
      AND m.id_documento_origen = p_id_comprobante
      AND (v_id_tipo_entrada_compra IS NULL OR m.id_tipo_movimiento = v_id_tipo_entrada_compra);

    IF cardinality(v_ids_balones_compra) > 0 THEN
        SELECT b.codigo_balon, COALESCE(eb.nombre, 'sin estado') AS estado_balon
        INTO v_balon_ocupado
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.id = ANY (v_ids_balones_compra)
          AND b.estado = 1
          AND COALESCE(eb.nombre, '') <> 'DISPONIBLE'
        LIMIT 1;

        IF FOUND THEN
            RETURN json_build_object(
                'eliminado', FALSE, 'id', p_id_comprobante,
                'error', format(
                    'No se puede anular: el cilindro %s comprado con esta factura ya no está disponible en almacén (estado %s).',
                    v_balon_ocupado.codigo_balon, v_balon_ocupado.estado_balon
                )
            );
        END IF;
    END IF;

    FOR v_detalle IN
        WITH ingresos AS (
            SELECT
                d.id_producto,
                COALESCE(d.id_almacen, v_id_almacen_default) AS id_almacen,
                d.cantidad
            FROM com_comprobante_compra_detalle d
            WHERE d.id_comprobante = p_id_comprobante
              AND d.afecta_stock = TRUE
              AND d.estado = 1

            UNION ALL

            SELECT
                m.id_producto,
                CASE
                    WHEN m.naturaleza = 'PRODUCTO' THEN m.id_almacen_origen
                    ELSE COALESCE(m.id_almacen_destino, m.id_almacen_origen)
                END AS id_almacen,
                m.cantidad
            FROM inv_movimiento m
            WHERE m.estado = 1
              AND m.id_producto IS NOT NULL
              AND m.stock_anterior IS NOT NULL
              AND m.stock_nuevo IS NOT NULL
              AND m.stock_nuevo >= m.stock_anterior
              AND v_id_tipo_doc_compra IS NOT NULL
              AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
              AND m.id_documento_origen = p_id_comprobante
              AND NOT (
                  m.naturaleza = 'PRODUCTO'
                  AND EXISTS (
                      SELECT 1 FROM gen_lista_opciones lo
                      WHERE lo.id = m.id_tipo_movimiento
                        AND UPPER(lo.nombre) = 'TRASLADO'
                  )
              )
              AND NOT (
                  m.naturaleza = 'PRODUCTO'
                  AND m.id_documento_detalle IN (
                      SELECT d2.id FROM com_comprobante_compra_detalle d2
                      WHERE d2.id_comprobante = p_id_comprobante
                        AND d2.afecta_stock = TRUE
                        AND d2.estado = 1
                  )
              )
        )
        SELECT id_producto, id_almacen, SUM(cantidad) AS cantidad
        FROM ingresos
        WHERE id_producto IS NOT NULL AND id_almacen IS NOT NULL
        GROUP BY id_producto, id_almacen
    LOOP
        SELECT stock INTO v_stock_actual
        FROM pro_stock
        WHERE id_producto = v_detalle.id_producto
          AND id_almacen = v_detalle.id_almacen
          AND estado = 1
        FOR UPDATE;

        v_stock_actual := COALESCE(v_stock_actual, 0);

        IF v_stock_actual < v_detalle.cantidad THEN
            SELECT nombre INTO v_nombre_producto FROM pro_producto WHERE id = v_detalle.id_producto;
            SELECT nombre INTO v_nombre_almacen FROM gen_almacen WHERE id = v_detalle.id_almacen;

            v_faltantes := v_faltantes || format(
                E'\n- %s en %s: a revertir %s, disponible %s, falta %s',
                v_nombre_producto, v_nombre_almacen,
                v_detalle.cantidad, v_stock_actual, (v_detalle.cantidad - v_stock_actual)
            );
        END IF;
    END LOOP;

    IF v_faltantes <> '' THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id_comprobante,
            'error', 'No se puede anular: el stock ya fue consumido por ventas u otros movimientos posteriores. Regularice el inventario antes de anular.' || v_faltantes
        );
    END IF;

    v_result_movimiento := inv_revertir_por_documento(
        'COMPRA',
        p_id_comprobante,
        p_id_usuario_auditoria
    );
    IF (v_result_movimiento->>'error') IS NOT NULL THEN
        RAISE EXCEPTION 'No se pudo anular: %', v_result_movimiento->>'error';
    END IF;

    UPDATE com_comprobante_compra
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    UPDATE com_comprobante_compra_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id_comprobante;

    IF cardinality(v_ids_balones_compra) > 0 THEN
        UPDATE bal_balon
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = ANY (v_ids_balones_compra)
          AND estado = 1;
    END IF;

    FOR v_orden IN
        SELECT id
        FROM doc_salida
        WHERE id_comprobante_compra = p_id_comprobante
          AND estado = 1
        FOR UPDATE
    LOOP
        UPDATE doc_salida
        SET
            id_comprobante_compra = NULL,
            serie_factura = NULL,
            numero_factura = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_orden.id;

        PERFORM bal_sincronizar_gas_retorno_planta(v_orden.id, p_id_usuario_auditoria);
    END LOOP;

    UPDATE bal_movimiento_recarga
    SET
        id_comprobante_compra = NULL,
        serie_factura = NULL,
        numero_factura = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante_compra = p_id_comprobante
      AND estado = 1;

    FOR v_id_cuenta_padre IN
        SELECT fc.id
        FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante
          AND fc.estado = 1
          AND fc.id_cuenta_padre IS NULL
    LOOP
        UPDATE fin_cuenta
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_cuenta_padre
           OR id_cuenta_padre = v_id_cuenta_padre;
    END LOOP;

    PERFORM com_refrescar_caja_compra(
        v_pago_caja, NULL,
        'Compra #' || p_id_comprobante || ' sin efectivo anulada con la caja cerrada',
        p_id_usuario_auditoria
    );

    RETURN json_build_object('eliminado', TRUE, 'id', p_id_comprobante);
END;
$function$;

-- Recalcula base imponible, IGV y total de una compra desde su detalle
DROP FUNCTION IF EXISTS public.com_recalcular_totales_compra (
  p_id_comprobante integer,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.com_recalcular_totales_compra (
  p_id_comprobante integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS void LANGUAGE plpgsql AS $function$
DECLARE
    v_total_bruto     NUMERIC(12,4);
    v_tasa_igv        NUMERIC(7,4);
    v_base_imponible  NUMERIC(12,4);
    v_igv_calculado   NUMERIC(12,4);
    v_pago_antes      JSONB;
    v_err             TEXT;
BEGIN
    v_pago_antes := com_pago_caja_compra(p_id_comprobante);

    SELECT COALESCE(SUM(importe), 0) INTO v_total_bruto
    FROM com_comprobante_compra_detalle
    WHERE id_comprobante = p_id_comprobante AND estado = 1;

    SELECT COALESCE(porcentaje_igv, 18) / 100 INTO v_tasa_igv
    FROM com_comprobante_compra
    WHERE id = p_id_comprobante;
    v_tasa_igv := COALESCE(v_tasa_igv, 0.18);

    v_base_imponible := ROUND(v_total_bruto / (1 + v_tasa_igv), 4);
    v_igv_calculado := v_total_bruto - v_base_imponible;

    UPDATE com_comprobante_compra
    SET sub_total = v_base_imponible,
        igv = v_igv_calculado,
        total_importe = v_total_bruto,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    PERFORM com_sincronizar_cxp_compra(p_id_comprobante, p_id_usuario_auditoria);

    v_err := com_assert_caja_compra(v_pago_antes, com_pago_caja_compra(p_id_comprobante));
    IF v_err IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err;
    END IF;

    PERFORM com_refrescar_caja_compra(
        v_pago_antes, com_pago_caja_compra(p_id_comprobante),
        'Compra #' || p_id_comprobante || ' sin efectivo corregida con la caja cerrada',
        p_id_usuario_auditoria
    );
END;
$function$;

-- Actualiza compra cabecera
DROP FUNCTION IF EXISTS public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying,
  p_id_condicion_pago integer,
  p_id_categoria_gasto integer,
  p_declarar_sunat boolean,
  p_id_usuario_auditoria integer,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying
);

DROP FUNCTION IF EXISTS public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying,
  p_id_condicion_pago integer,
  p_id_categoria_gasto integer,
  p_declarar_sunat boolean,
  p_id_usuario_auditoria integer,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying,
  p_porcentaje_igv numeric
);

DROP FUNCTION IF EXISTS public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying,
  p_id_condicion_pago integer,
  p_id_categoria_gasto integer,
  p_declarar_sunat boolean,
  p_id_usuario_auditoria integer,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying,
  p_porcentaje_igv numeric,
  p_fecha date,
  p_fecha_emision date,
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying
);

-- p_fecha es la FECHA DE GASTO: cambiarla mueve el pago a la caja de la nueva fecha (debe estar abierta);
-- si la caja de origen ya estaba cerrada se recalcula su arqueo. Comprobante (tipo, serie, número, emisión)
-- se completa sin tocar la caja. NULL = conservar; para vaciar: p_serie/p_numero '', p_id_tipo_comprobante 0,
-- p_quitar_fecha_emision TRUE (la compra vuelve a "pendiente de comprobante").
CREATE OR REPLACE FUNCTION public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying DEFAULT NULL::character varying,
  p_id_condicion_pago integer DEFAULT NULL::integer,
  p_id_categoria_gasto integer DEFAULT NULL::integer,
  p_declarar_sunat boolean DEFAULT NULL::boolean,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_fecha_vencimiento_cxp date DEFAULT NULL::date,
  p_cuotas_cxp jsonb DEFAULT NULL::jsonb,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_id_cuenta_bancaria integer DEFAULT NULL::integer,
  p_numero_operacion character varying DEFAULT NULL::character varying,
  p_porcentaje_igv numeric DEFAULT NULL::numeric,
  p_fecha date DEFAULT NULL::date,
  p_fecha_emision date DEFAULT NULL::date,
  p_id_tipo_comprobante integer DEFAULT NULL::integer,
  p_serie character varying DEFAULT NULL::character varying,
  p_numero character varying DEFAULT NULL::character varying,
  p_quitar_fecha_emision boolean DEFAULT FALSE
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_pago_antes JSONB;
    v_pago_despues JSONB;
    v_tenia_cxp BOOLEAN;
    v_err TEXT;
    v_porcentaje_igv NUMERIC(5,2);
    v_compra RECORD;
    v_mueve_fecha BOOLEAN := FALSE;
    v_id_sesion_origen INTEGER;
    v_arqueo JSON;
    v_observacion TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_emision IS NOT NULL AND p_fecha_emision > CURRENT_DATE THEN
        RETURN json_build_object('error', 'La fecha de emisión no puede ser posterior a hoy', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante AND estado = 1) THEN
        RETURN json_build_object('error', 'La compra no existe o está anulada', 'registro', NULL);
    END IF;

    IF fin_medio_pago_flag(p_id_medio_pago, 'ES_CREDITO') THEN
        RETURN json_build_object('error', 'El medio de pago de la compra no puede ser crédito: para una compra al crédito elige la condición de pago.', 'registro', NULL);
    END IF;

    IF p_id_medio_pago IS NOT NULL THEN
        v_err := fin_validar_cuenta_medio_pago(p_id_medio_pago, p_id_cuenta_bancaria);
        IF v_err IS NOT NULL THEN
            RETURN json_build_object('error', v_err, 'registro', NULL);
        END IF;
    END IF;

    IF p_porcentaje_igv IS NOT NULL THEN
        v_porcentaje_igv := ROUND(p_porcentaje_igv, 2);
        IF v_porcentaje_igv < 0 OR v_porcentaje_igv > 100 THEN
            RETURN json_build_object('error', 'El porcentaje de IGV debe estar entre 0 y 100', 'registro', NULL);
        END IF;
    END IF;

    SELECT id, fecha, id_sucursal, total_importe INTO v_compra
    FROM com_comprobante_compra WHERE id = p_id_comprobante;
    v_mueve_fecha := p_fecha IS NOT NULL AND p_fecha <> v_compra.fecha;

    v_pago_antes := com_pago_caja_compra(p_id_comprobante);
    v_tenia_cxp := EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante AND fc.estado = 1
    );

    UPDATE com_comprobante_compra
    SET glosa               = COALESCE(p_glosa, glosa),
        id_condicion_pago   = COALESCE(p_id_condicion_pago, id_condicion_pago),
        id_categoria_gasto  = COALESCE(p_id_categoria_gasto, id_categoria_gasto),
        declarar_sunat      = COALESCE(p_declarar_sunat, declarar_sunat),
        id_medio_pago       = COALESCE(p_id_medio_pago, id_medio_pago),
        id_cuenta_bancaria  = CASE WHEN p_id_medio_pago IS NOT NULL THEN p_id_cuenta_bancaria ELSE id_cuenta_bancaria END,
        numero_operacion    = CASE WHEN p_id_medio_pago IS NOT NULL THEN NULLIF(TRIM(p_numero_operacion), '') ELSE numero_operacion END,
        porcentaje_igv      = COALESCE(v_porcentaje_igv, porcentaje_igv),
        fecha               = COALESCE(p_fecha, fecha),
        fecha_emision       = CASE WHEN COALESCE(p_quitar_fecha_emision, FALSE) THEN NULL
                                   ELSE COALESCE(p_fecha_emision, fecha_emision) END,
        id_tipo_comprobante = CASE WHEN p_id_tipo_comprobante = 0 THEN NULL
                                   ELSE COALESCE(p_id_tipo_comprobante, id_tipo_comprobante) END,
        serie               = CASE WHEN p_serie IS NULL THEN serie ELSE NULLIF(TRIM(p_serie), '') END,
        numero              = CASE WHEN p_numero IS NULL THEN numero ELSE NULLIF(TRIM(p_numero), '') END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion  = NOW()
    WHERE id = p_id_comprobante;

    IF v_porcentaje_igv IS NOT NULL THEN
        UPDATE com_comprobante_compra
        SET sub_total = ROUND(COALESCE(total_importe, 0) / (1 + v_porcentaje_igv / 100), 4),
            igv       = COALESCE(total_importe, 0) - ROUND(COALESCE(total_importe, 0) / (1 + v_porcentaje_igv / 100), 4)
        WHERE id = p_id_comprobante;
    END IF;

    PERFORM com_sincronizar_cxp_compra(
        p_id_comprobante,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    IF EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante AND fc.estado = 1
    ) THEN
        UPDATE com_comprobante_compra
        SET id_medio_pago = NULL, id_cuenta_bancaria = NULL, numero_operacion = NULL
        WHERE id = p_id_comprobante;
    ELSIF v_tenia_cxp AND EXISTS (
        SELECT 1 FROM com_comprobante_compra
        WHERE id = p_id_comprobante AND id_medio_pago IS NULL AND COALESCE(total_importe, 0) > 0
    ) THEN
        RAISE EXCEPTION 'Indica el medio de pago: al pasar la compra a contado se paga en el momento.';
    END IF;

    v_pago_despues := com_pago_caja_compra(p_id_comprobante);
    IF v_mueve_fecha
       AND v_pago_antes->'idMedioPago' IS NOT DISTINCT FROM v_pago_despues->'idMedioPago'
       AND v_pago_antes->'monto' IS NOT DISTINCT FROM v_pago_despues->'monto' THEN
        -- Solo se mueve la fecha de gasto: basta la caja de destino abierta (decisión de negocio);
        -- la de origen puede estar cerrada y su arqueo se recalcula abajo.
        v_err := com_assert_caja_compra(NULL, v_pago_despues);
    ELSE
        -- Cambios de medio/monto (con o sin cambio de fecha) validan origen y destino como siempre.
        v_err := com_assert_caja_compra(v_pago_antes, v_pago_despues);
    END IF;
    IF v_err IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err;
    END IF;

    PERFORM com_refrescar_caja_compra(
        CASE WHEN v_mueve_fecha THEN NULL ELSE v_pago_antes END,
        v_pago_despues,
        'Compra #' || p_id_comprobante || ' sin efectivo corregida con la caja cerrada',
        p_id_usuario_auditoria
    );

    -- Cualquier pago al contado (con o sin efectivo) figura en los totales de la caja de origen.
    IF v_mueve_fecha AND v_pago_antes IS NOT NULL THEN
        SELECT s.id INTO v_id_sesion_origen
        FROM fin_caja_sesion s
        WHERE s.estado = 1
          AND s.fecha = v_compra.fecha
          AND COALESCE(s.id_sucursal, 0) = COALESCE(v_compra.id_sucursal, 0)
        ORDER BY s.id DESC
        LIMIT 1;

        IF v_id_sesion_origen IS NOT NULL THEN
            -- NULL si la caja de origen sigue abierta: sus totales se recalculan solos en vivo.
            v_arqueo := fin_caja_recalcular_arqueo(v_id_sesion_origen, p_id_usuario_auditoria);

            SELECT 'Compra ' || COALESCE(c.serie || '-' || c.numero, '#' || c.id)
                   || ' movida al ' || to_char(p_fecha, 'DD/MM/YYYY')
            INTO v_observacion
            FROM com_comprobante_compra c WHERE c.id = p_id_comprobante;

            IF v_arqueo IS NOT NULL THEN
                v_observacion := v_observacion || ' · arqueo recalculado, esperado '
                    || ROUND(COALESCE((v_arqueo->>'montoEsperadoAnterior')::NUMERIC, 0), 2)
                    || ' → ' || ROUND((v_arqueo->>'montoEsperado')::NUMERIC, 2);
            END IF;

            INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, diferencia, observacion, id_usuario)
            VALUES (
                v_id_sesion_origen, 'AJUSTE_COMPRA', (v_pago_antes->>'monto')::NUMERIC,
                (v_arqueo->>'diferencia')::NUMERIC, LEFT(v_observacion, 500), p_id_usuario_auditoria
            );
        END IF;
    END IF;

    RETURN com_obtener_compra(p_id_comprobante);
END;
$function$;

-- Indica si los cobros de una venta (líneas o, sin líneas, el medio de cabecera) mueven efectivo de la caja
DROP FUNCTION IF EXISTS public.ven_pagos_mueven_efectivo (
  p_pagos json,
  p_id_medio_pago integer,
  p_id_condicion_pago integer
);

CREATE OR REPLACE FUNCTION public.ven_pagos_mueven_efectivo (
  p_pagos json DEFAULT NULL::json,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_id_condicion_pago integer DEFAULT NULL::integer
) RETURNS boolean LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_es_credito BOOLEAN := FALSE;
BEGIN
    IF p_pagos IS NOT NULL
       AND json_typeof(p_pagos) = 'array'
       AND json_array_length(p_pagos) > 0 THEN
        -- Una línea sin medio se trata como efectivo (criterio conservador: exige la caja).
        RETURN EXISTS (
            SELECT 1
            FROM json_array_elements(p_pagos) j
            WHERE NULLIF(j.value ->> 'idMedioPago', '') IS NULL
               OR fin_medio_pago_flag((j.value ->> 'idMedioPago')::INTEGER, 'ES_EFECTIVO')
        );
    END IF;

    -- Sin líneas de cobro la venta se cobra con la cabecera (mismo criterio que ven_pagos_de_comprobante).
    SELECT COALESCE(cp.dias_credito, 0) > 0 OR COALESCE(cp.numero_cuotas, 0) > 1
    INTO v_es_credito
    FROM gen_condicion_pago cp
    WHERE cp.id = p_id_condicion_pago;

    IF COALESCE(v_es_credito, FALSE) THEN
        RETURN FALSE;
    END IF;

    -- Sin medio, la caja lo cuenta como efectivo (fin_caja_calcular_totales).
    IF p_id_medio_pago IS NULL THEN
        RETURN TRUE;
    END IF;

    RETURN fin_medio_pago_flag(p_id_medio_pago, 'ES_EFECTIVO');
END;
$function$;

-- Obtiene comprobante por id
DROP FUNCTION IF EXISTS public.ven_obtener_comprobante (p_id integer);

CREATE OR REPLACE FUNCTION public.ven_obtener_comprobante (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
    v_detalles JSON;
    v_cuotas JSON;
    v_pagos JSON;
    v_prestamos JSON;
    v_garantias JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            c.id,
            c.xmin::text AS version,
            ven_comprobante_permite_edicion(c) AS permite_edicion_segura,
            EXISTS(SELECT 1 FROM ven_vsd_operacion o WHERE o.id_comprobante=c.id AND o.tipo='CAMBIO_BALON' AND o.datos->>'tipoOperacion'='CAMBIO') AS tiene_cambio_fisico,
            c.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            tc.descripcion AS codigo_tipo_comprobante,
            c.serie,
            c.numero,
            c.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            c.id_tipo_operacion_sunat,
            tos.nombre AS nombre_tipo_operacion_sunat,
            tos.descripcion AS codigo_tipo_operacion_sunat,
            c.id_comprobante_origen,
            co.serie AS serie_comprobante_origen,
            co.numero AS numero_comprobante_origen,
            tc_origen.descripcion AS codigo_tipo_comprobante_origen,
            tc_origen.nombre AS nombre_tipo_comprobante_origen,
            c.id_motivo_nota,
            mn.nombre AS nombre_motivo_nota,
            mn.descripcion AS codigo_motivo_nota,
            c.ticket_sunat,
            c.hash_documento,
            c.xml_firmado,
            c.cdr_respuesta,
            c.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            c.id_tipo_venta,
            tv.nombre AS nombre_tipo_venta,
            c.fecha,
            c.fecha_venta,
            COALESCE(c.fecha_venta, c.fecha) AS fecha_caja,
            c.fecha_vencimiento,
            c.tipo_cambio,
            c.id_cliente,
            COALESCE(
                cl.razon_social,
                TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
            ) AS nombre_cliente,
            cl.numero_documento AS documento_cliente,
            c.id_sucursal,
            su.nombre AS nombre_sucursal,
            c.id_almacen,
            al.nombre AS nombre_almacen,
            c.id_condicion_pago,
            cp.nombre AS nombre_condicion_pago,
            COALESCE(cp.dias_credito, 0) AS dias_credito,
            COALESCE(cp.numero_cuotas, 0) AS numero_cuotas,
            c.id_moneda,
            mo.nombre AS nombre_moneda,
            mo.descripcion AS codigo_moneda,
            c.id_medio_pago,
            mp.nombre AS nombre_medio_pago,
            c.sub_total,
            c.descuento,
            c.valor_venta,
            c.igv,
            c.total_importe,
            c.anticipos,
            c.exonerado,
            c.glosa,
            c.observaciones,
            c.periodo_contable,
            c.operacion,
            c.origen_pos,
            c.id_estado,
            ed.nombre AS nombre_estado,
            c.estado,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            act.id AS id_actividad,
            act.titulo AS titulo_actividad,
            act.nombre_tipo_actividad,
            act.nombre_estado_actividad,
            act.nombre_chofer_responsable,
            (act.id IS NOT NULL) AS tiene_actividad,
            docsal.id AS id_doc_salida,
            docsal.numero AS numero_doc_salida
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
        LEFT JOIN gen_lista_opciones tos ON c.id_tipo_operacion_sunat = tos.id
        LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
        LEFT JOIN gen_lista_opciones tc_origen ON co.id_tipo_comprobante = tc_origen.id
        LEFT JOIN gen_lista_opciones mn ON c.id_motivo_nota = mn.id
        LEFT JOIN gen_lista_opciones tm ON c.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tv ON c.id_tipo_venta = tv.id
        LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
        LEFT JOIN gen_sucursal su ON c.id_sucursal = su.id
        LEFT JOIN gen_almacen al ON c.id_almacen = al.id
        LEFT JOIN gen_condicion_pago cp ON c.id_condicion_pago = cp.id
        LEFT JOIN gen_lista_opciones mo ON c.id_moneda = mo.id
        LEFT JOIN gen_lista_opciones mp ON c.id_medio_pago = mp.id
        LEFT JOIN gen_lista_opciones ed ON c.id_estado = ed.id
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON c.id_usuario_modificacion = um.id
        LEFT JOIN LATERAL (
            SELECT
                a.id,
                a.titulo,
                ta.nombre AS nombre_tipo_actividad,
                ea.nombre AS nombre_estado_actividad,
                TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            LEFT JOIN gen_chofer ch ON ch.id = a.id_chofer_responsable
            WHERE (
                    a.id_comprobante = c.id
                    OR a.id_doc_salida IN (
                        SELECT ds.id
                        FROM doc_salida ds
                        WHERE ds.id_venta = c.id AND ds.estado = 1
                    )
                  )
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
            ORDER BY a.id DESC
            LIMIT 1
        ) act ON TRUE
        LEFT JOIN LATERAL (
            SELECT d.id, d.numero
            FROM doc_salida d
            JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
            WHERE d.id_venta = c.id
              AND d.estado = 1
              AND ec.nombre <> 'ANULADA'
            ORDER BY d.id DESC
            LIMIT 1
        ) docsal ON TRUE
        WHERE c.id = p_id AND c.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.item), '[]'::JSON) INTO v_detalles
    FROM (
        SELECT
            d.id,
            d.id_comprobante,
            d.item,
            d.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            p.es_gas,
            p.es_servicio,
            p.es_alquilable,
            d.descripcion,
            d.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            d.cantidad,
            COALESCE((
                SELECT SUM(nd.cantidad)
                FROM ven_comprobante nc
                INNER JOIN gen_lista_opciones tc
                    ON tc.id = nc.id_tipo_comprobante
                   AND tc.descripcion = '07'
                INNER JOIN ven_comprobante_detalle nd
                    ON nd.id_comprobante = nc.id
                   AND nd.estado = 1
                   AND nd.id_producto = d.id_producto
                LEFT JOIN gen_lista_opciones es ON es.id = nc.id_estado_sunat
                WHERE nc.id_comprobante_origen = p_id
                  AND nc.estado = 1
                  AND COALESCE(es.nombre, '') NOT IN ('BAJA')
            ), 0) AS cantidad_nc_previa,
            GREATEST(
                d.cantidad - COALESCE((
                    SELECT SUM(nd.cantidad)
                    FROM ven_comprobante nc
                    INNER JOIN gen_lista_opciones tc
                        ON tc.id = nc.id_tipo_comprobante
                       AND tc.descripcion = '07'
                    INNER JOIN ven_comprobante_detalle nd
                        ON nd.id_comprobante = nc.id
                       AND nd.estado = 1
                       AND nd.id_producto = d.id_producto
                    LEFT JOIN gen_lista_opciones es ON es.id = nc.id_estado_sunat
                    WHERE nc.id_comprobante_origen = p_id
                      AND nc.estado = 1
                      AND COALESCE(es.nombre, '') NOT IN ('BAJA')
                ), 0),
                0
            ) AS cantidad_disponible_nc,
            d.precio_unitario,
            d.descuento,
            d.valor_venta,
            d.porcentaje_igv,
            d.id_afectacion_igv,
            ai.nombre AS nombre_afectacion_igv,
            ai.descripcion AS codigo_afectacion_igv,
            d.impuesto,
            d.importe,
            d.id_balon,
            b.codigo_balon,
            d.capacidad_cilindro,
            d.id_estado_cilindro,
            ec.nombre AS nombre_estado_cilindro,
            (COALESCE(d.descripcion, '') ~* 'garant[ií]a') AS es_linea_garantia,
            d.estado,
            d.fecha_creacion,
            d.fecha_modificacion
        FROM ven_comprobante_detalle d
        LEFT JOIN pro_producto p ON d.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON d.id_unidad_medida = um.id
        LEFT JOIN gen_lista_opciones ai ON d.id_afectacion_igv = ai.id
        LEFT JOIN bal_balon b ON d.id_balon = b.id
        LEFT JOIN gen_lista_opciones ec ON d.id_estado_cilindro = ec.id
        WHERE d.id_comprobante = p_id AND d.estado = 1
    ) d;

    SELECT COALESCE(json_agg(row_to_json(q) ORDER BY q.numero_cuota), '[]'::JSON) INTO v_cuotas
    FROM (
        SELECT
            q.id,
            q.id_comprobante,
            q.numero_cuota,
            q.fecha_vencimiento,
            q.monto,
            q.monto_pagado,
            q.id_estado,
            eq.nombre AS nombre_estado,
            q.estado,
            q.fecha_creacion,
            q.fecha_modificacion
        FROM ven_cuotas q
        LEFT JOIN gen_lista_opciones eq ON q.id_estado = eq.id
        WHERE q.id_comprobante = p_id AND q.estado = 1
    ) q;

    SELECT COALESCE(json_agg(row_to_json(pg) ORDER BY pg.item), '[]'::JSON) INTO v_pagos
    FROM (
        SELECT
            pp.id,
            pp.item,
            pp.id_medio_pago,
            mp.nombre AS nombre_medio_pago,
            pp.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS cuenta_bancaria,
            pp.monto,
            pp.numero_operacion,
            pp.referencia,
            pp.observacion
        FROM ven_comprobante_pago pp
        LEFT JOIN gen_lista_opciones mp ON mp.id = pp.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = pp.id_cuenta_bancaria
        WHERE pp.id_comprobante = p_id AND pp.estado = 1
    ) pg;

    SELECT COALESCE(json_agg(row_to_json(pr) ORDER BY pr.id), '[]'::JSON) INTO v_prestamos
    FROM (
        SELECT
            p.id,
            p.numero_prestamo,
            p.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            p.id_almacen,
            a.nombre AS nombre_almacen,
            p.fecha_salida,
            p.fecha_retorno_pactada,
            p.fecha_retorno_real,
            p.titulo,
            p.observacion,
            p.id_estado,
            ep.nombre AS nombre_estado,
            p.id_prestamo_origen,
            po.numero_prestamo AS numero_prestamo_origen,
            (
                SELECT COALESCE(json_agg(row_to_json(bl) ORDER BY bl.rol, bl.id), '[]'::JSON)
                FROM (
                    SELECT
                        pd.id,
                        pd.rol,
                        pd.id_balon,
                        b.codigo_balon,
                        b.numero_serie,
                        b.id_tipo_balon,
                        tb.nombre AS nombre_tipo_balon,
                        tb.capacidad,
                        b.id_estado_balon,
                        eb.nombre AS nombre_estado_balon,
                        pd.id_producto,
                        COALESCE(pgas.nombre, prod.nombre) AS nombre_producto,
                        pd.fecha_entregado,
                        pd.fecha_prestamo,
                        pd.fecha_vencimiento,
                        pd.fecha_devolucion,
                        pd.id_estado,
                        epd.nombre AS nombre_estado,
                        pd.motivo_especifico,
                        pd.observacion
                    FROM bal_prestamo_detalle pd
                    LEFT JOIN bal_balon b ON b.id = pd.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
                    LEFT JOIN pro_producto prod ON prod.id = pd.id_producto
                    LEFT JOIN pro_producto pgas ON pgas.id = b.id_producto_gas
                    LEFT JOIN gen_lista_opciones epd ON epd.id = pd.id_estado
                    WHERE pd.id_prestamo = p.id AND pd.estado = 1
                ) bl
            ) AS balones
        FROM bal_prestamo p
        LEFT JOIN gen_lista_opciones tp ON tp.id = p.id_tipo_prestamo
        LEFT JOIN gen_almacen a ON a.id = p.id_almacen
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        LEFT JOIN bal_prestamo po ON po.id = p.id_prestamo_origen
        WHERE p.id_comprobante_venta = p_id AND p.estado = 1
    ) pr;

    SELECT COALESCE(json_agg(row_to_json(gr) ORDER BY gr.id), '[]'::JSON) INTO v_garantias
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            g.id_prestamo,
            pr.numero_prestamo,
            g.id_alquiler,
            alq.numero_alquiler,
            g.id_producto,
            prod.nombre AS nombre_producto,
            g.cantidad_venta,
            g.id_unidad_medida,
            umg.nombre AS nombre_unidad_medida,
            g.ubicacion,
            g.fecha_registro,
            g.monto_cobrado,
            g.monto_devuelto,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.id_medio_pago,
            mpg.nombre AS nombre_medio_pago,
            g.observacion,
            COALESCE((
                SELECT SUM(gm.monto)
                FROM ven_garantia_movimiento gm
                INNER JOIN gen_lista_opciones tmg ON tmg.id = gm.id_tipo_movimiento
                WHERE gm.id_garantia = g.id
                  AND gm.id_comprobante = p_id
                  AND gm.estado = 1
                  AND UPPER(tmg.nombre) = 'COBRO'
            ), 0) AS monto_cobrado_comprobante
        FROM ven_garantia g
        LEFT JOIN bal_prestamo pr ON pr.id = g.id_prestamo
        LEFT JOIN bal_alquiler alq ON alq.id = g.id_alquiler
        LEFT JOIN pro_producto prod ON prod.id = g.id_producto
        LEFT JOIN gen_lista_opciones umg ON umg.id = g.id_unidad_medida
        LEFT JOIN gen_lista_opciones eg ON eg.id = g.id_estado
        LEFT JOIN gen_lista_opciones mpg ON mpg.id = g.id_medio_pago
        WHERE g.estado = 1
          AND (
              pr.id_comprobante_venta = p_id
              OR alq.id_comprobante_venta = p_id
              OR EXISTS (
                  SELECT 1
                  FROM ven_garantia_movimiento gm
                  WHERE gm.id_garantia = g.id
                    AND gm.id_comprobante = p_id
                    AND gm.estado = 1
              )
          )
    ) gr;

    RETURN json_build_object(
        'registro', v_registro,
        'detalles', v_detalles,
        'cuotas', v_cuotas,
        'pagos', v_pagos,
        'prestamos', v_prestamos,
        'garantias', v_garantias
    );
END;
$function$;

-- Lista comprobantes con filtros y paginación
DROP FUNCTION IF EXISTS public.ven_listar_comprobantes (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_tipo_comprobante integer,
  p_id_cliente integer,
  p_id_estado integer,
  p_id_estado_sunat integer,
  p_fecha_desde date,
  p_fecha_hasta date,
  p_serie character varying,
  p_solo_activos integer
);

CREATE OR REPLACE FUNCTION public.ven_listar_comprobantes (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_tipo_comprobante integer DEFAULT NULL::integer,
  p_id_cliente integer DEFAULT NULL::integer,
  p_id_estado integer DEFAULT NULL::integer,
  p_id_estado_sunat integer DEFAULT NULL::integer,
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_serie character varying DEFAULT NULL::character varying,
  p_solo_activos integer DEFAULT 1
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_busqueda TEXT;
    v_busqueda_norm TEXT;
    v_busqueda_sin_guion TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_busqueda := TRIM(COALESCE(p_busqueda, ''));
    v_busqueda_norm := LOWER(REPLACE(REPLACE(v_busqueda, ' ', ''), '/', '-'));
    v_busqueda_sin_guion := REPLACE(v_busqueda_norm, '-', '');

    SELECT COUNT(*) INTO v_total
    FROM ven_comprobante c
    LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
    LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
    WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
      AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
      AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
      AND (p_id_estado IS NULL OR c.id_estado = p_id_estado)
      AND (p_id_estado_sunat IS NULL OR c.id_estado_sunat = p_id_estado_sunat)
      AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
      AND (p_serie IS NULL OR p_serie = '' OR c.serie = TRIM(p_serie))
      AND (
          v_busqueda = ''
          OR LOWER(c.serie) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.numero) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.serie || '-' || c.numero) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.serie || c.numero) LIKE '%' || v_busqueda_sin_guion || '%'
          OR LOWER(COALESCE(co.serie, '')) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(COALESCE(co.serie, '') || '-' || COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
          OR gen_texto_coincide(cli_texto_busqueda(cl), v_busqueda)
          OR gen_texto_coincide(COALESCE(cl.numero_documento, ''), v_busqueda)
          OR gen_texto_coincide(COALESCE(c.glosa, ''), v_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            c.id,
            c.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            tc.descripcion AS codigo_tipo_comprobante,
            c.serie,
            c.numero,
            c.fecha,
            c.fecha_venta,
            c.id_cliente,
            COALESCE(
                cl.razon_social,
                TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
            ) AS nombre_cliente,
            cl.numero_documento AS documento_cliente,
            c.id_estado,
            ed.nombre AS nombre_estado,
            c.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            c.id_comprobante_origen,
            co.serie AS serie_comprobante_origen,
            co.numero AS numero_comprobante_origen,
            tc_origen.descripcion AS codigo_tipo_comprobante_origen,
            tc_origen.nombre AS nombre_tipo_comprobante_origen,
            cd.id AS id_comprobante_destino,
            cd.serie AS serie_comprobante_destino,
            cd.numero AS numero_comprobante_destino,
            tc_destino.descripcion AS codigo_tipo_comprobante_destino,
            tc_destino.nombre AS nombre_tipo_comprobante_destino,
            c.id_motivo_nota,
            mn.nombre AS nombre_motivo_nota,
            mn.descripcion AS codigo_motivo_nota,
            c.total_importe,
            c.id_moneda,
            mo.nombre AS nombre_moneda,
            act.id AS id_actividad,
            act.titulo AS titulo_actividad,
            act.nombre_tipo_actividad,
            act.nombre_estado_actividad,
            (act.id IS NOT NULL) AS tiene_actividad,
            docsal.id AS id_doc_salida,
            docsal.numero AS numero_doc_salida,
            c.estado,
            c.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_comprobante_detalle d
                WHERE d.id_comprobante = c.id AND d.estado = 1
            ) AS total_detalles
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
        LEFT JOIN gen_lista_opciones tc_origen ON co.id_tipo_comprobante = tc_origen.id
        LEFT JOIN LATERAL (
            SELECT d.id, d.serie, d.numero, d.id_tipo_comprobante
            FROM ven_comprobante d
            WHERE d.id_comprobante_origen = c.id AND d.estado = 1
            ORDER BY d.id DESC
            LIMIT 1
        ) cd ON TRUE
        LEFT JOIN gen_lista_opciones tc_destino ON cd.id_tipo_comprobante = tc_destino.id
        LEFT JOIN gen_lista_opciones mn ON c.id_motivo_nota = mn.id
        LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
        LEFT JOIN gen_lista_opciones ed ON c.id_estado = ed.id
        LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
        LEFT JOIN gen_lista_opciones mo ON c.id_moneda = mo.id
        LEFT JOIN LATERAL (
            SELECT
                a.id,
                a.titulo,
                ta.nombre AS nombre_tipo_actividad,
                ea.nombre AS nombre_estado_actividad
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            WHERE (
                    a.id_comprobante = c.id
                    OR a.id_doc_salida IN (
                        SELECT ds.id
                        FROM doc_salida ds
                        WHERE ds.id_venta = c.id AND ds.estado = 1
                    )
                  )
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
            ORDER BY a.id DESC
            LIMIT 1
        ) act ON TRUE
        LEFT JOIN LATERAL (
            SELECT d.id, d.numero
            FROM doc_salida d
            JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
            WHERE d.id_venta = c.id
              AND d.estado = 1
              AND ec.nombre <> 'ANULADA'
            ORDER BY d.id DESC
            LIMIT 1
        ) docsal ON TRUE
        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_estado IS NULL OR c.id_estado = p_id_estado)
          AND (p_id_estado_sunat IS NULL OR c.id_estado_sunat = p_id_estado_sunat)
          AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
          AND (p_serie IS NULL OR p_serie = '' OR c.serie = TRIM(p_serie))
          AND (
              v_busqueda = ''
              OR LOWER(c.serie) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.numero) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.serie || '-' || c.numero) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.serie || c.numero) LIKE '%' || v_busqueda_sin_guion || '%'
              OR LOWER(COALESCE(co.serie, '')) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(COALESCE(co.serie, '') || '-' || COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
              OR gen_texto_coincide(cli_texto_busqueda(cl), v_busqueda)
              OR gen_texto_coincide(COALESCE(cl.numero_documento, ''), v_busqueda)
              OR gen_texto_coincide(COALESCE(c.glosa, ''), v_busqueda)
          )
        ORDER BY c.fecha DESC, c.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- Emite un comprobante de venta con detalles, cuotas y pagos, y aplica sus efectos (fecha de venta opcional para la caja)
DROP FUNCTION IF EXISTS public.ven_crear_comprobante (
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying,
  p_fecha date,
  p_id_cliente integer,
  p_detalles json,
  p_id_tipo_operacion_sunat integer,
  p_id_comprobante_origen integer,
  p_id_motivo_nota integer,
  p_id_tipo_movimiento integer,
  p_id_tipo_venta integer,
  p_fecha_vencimiento date,
  p_tipo_cambio numeric,
  p_id_sucursal integer,
  p_id_almacen integer,
  p_id_condicion_pago integer,
  p_id_moneda integer,
  p_id_medio_pago integer,
  p_glosa character varying,
  p_observaciones character varying,
  p_periodo_contable character varying,
  p_operacion character varying,
  p_id_estado integer,
  p_cuotas json,
  p_id_usuario_auditoria integer,
  p_origen_pos character varying,
  p_efectos_pos json,
  p_pagos json
);

DROP FUNCTION IF EXISTS public.ven_crear_comprobante (
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying,
  p_fecha date,
  p_id_cliente integer,
  p_detalles json,
  p_id_tipo_operacion_sunat integer,
  p_id_comprobante_origen integer,
  p_id_motivo_nota integer,
  p_id_tipo_movimiento integer,
  p_id_tipo_venta integer,
  p_fecha_vencimiento date,
  p_tipo_cambio numeric,
  p_id_sucursal integer,
  p_id_almacen integer,
  p_id_condicion_pago integer,
  p_id_moneda integer,
  p_id_medio_pago integer,
  p_glosa character varying,
  p_observaciones character varying,
  p_periodo_contable character varying,
  p_operacion character varying,
  p_id_estado integer,
  p_cuotas json,
  p_id_usuario_auditoria integer,
  p_origen_pos character varying,
  p_efectos_pos json,
  p_pagos json,
  p_fecha_venta date
);

CREATE OR REPLACE FUNCTION public.ven_crear_comprobante (
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying DEFAULT NULL::character varying,
  p_fecha date DEFAULT NULL::date,
  p_id_cliente integer DEFAULT NULL::integer,
  p_detalles json DEFAULT '[]'::json,
  p_id_tipo_operacion_sunat integer DEFAULT NULL::integer,
  p_id_comprobante_origen integer DEFAULT NULL::integer,
  p_id_motivo_nota integer DEFAULT NULL::integer,
  p_id_tipo_movimiento integer DEFAULT NULL::integer,
  p_id_tipo_venta integer DEFAULT NULL::integer,
  p_fecha_vencimiento date DEFAULT NULL::date,
  p_tipo_cambio numeric DEFAULT 3.5,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_id_condicion_pago integer DEFAULT NULL::integer,
  p_id_moneda integer DEFAULT NULL::integer,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_glosa character varying DEFAULT NULL::character varying,
  p_observaciones character varying DEFAULT NULL::character varying,
  p_periodo_contable character varying DEFAULT NULL::character varying,
  p_operacion character varying DEFAULT NULL::character varying,
  p_id_estado integer DEFAULT NULL::integer,
  p_cuotas json DEFAULT NULL::json,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_origen_pos character varying DEFAULT NULL::character varying,
  p_efectos_pos json DEFAULT NULL::json,
  p_pagos json DEFAULT NULL::json,
  p_fecha_venta date DEFAULT NULL::date
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_err_pagos TEXT;
    -- Fecha en que se hizo la venta: manda en la caja y el libro diario. p_fecha es la emisión (SUNAT, correlativo).
    v_fecha_venta DATE;
    v_mueve_efectivo BOOLEAN;
    -- Factura/boleta emitida desde una venta sin documento (NV/VSD): esa venta ya pasó por su caja.
    v_desde_vsd BOOLEAN := FALSE;
    v_fecha_venta_origen DATE;
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

    IF p_id_comprobante_origen IS NOT NULL THEN
        PERFORM 1 FROM ven_comprobante WHERE id=p_id_comprobante_origen FOR UPDATE;
    END IF;

    IF p_id_comprobante_origen IS NOT NULL AND EXISTS (
        SELECT 1 FROM ven_vsd_operacion WHERE id_comprobante=p_id_comprobante_origen AND tipo='CAMBIO_BALON' AND datos->>'tipoOperacion'='CAMBIO'
    ) THEN
        RAISE EXCEPTION 'La venta tiene cambios físicos registrados. Debe conciliarse antes de generar un documento derivado';
    END IF;

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

    IF p_id_sucursal IS NULL AND p_id_almacen IS NOT NULL THEN
        SELECT a.id_sucursal INTO p_id_sucursal
        FROM gen_almacen a
        WHERE a.id = p_id_almacen
          AND a.estado = 1
        LIMIT 1;
    END IF;

    IF p_id_comprobante_origen IS NOT NULL THEN
        SELECT
            UPPER(COALESCE(tori.descripcion, '')) IN ('NV', 'VSD')
                AND COALESCE(tnue.descripcion, '') IN ('01', '03'),
            COALESCE(ori.fecha_venta, ori.fecha)
        INTO v_desde_vsd, v_fecha_venta_origen
        FROM ven_comprobante ori
        JOIN gen_lista_opciones tori ON tori.id = ori.id_tipo_comprobante
        LEFT JOIN gen_lista_opciones tnue ON tnue.id = p_id_tipo_comprobante
        WHERE ori.id = p_id_comprobante_origen;
        v_desde_vsd := COALESCE(v_desde_vsd, FALSE);
    END IF;

    -- Desde una venta sin documento la fecha de venta es la de esa venta (se emite con la fecha de hoy).
    v_fecha_venta := COALESCE(
        p_fecha_venta,
        CASE WHEN v_desde_vsd THEN LEAST(v_fecha_venta_origen, p_fecha) END,
        p_fecha
    );

    IF v_fecha_venta > p_fecha THEN
        RETURN json_build_object(
            'error', format(
                'La fecha de venta (%s) no puede ser posterior a la fecha de emisión (%s)',
                to_char(v_fecha_venta, 'DD/MM/YYYY'), to_char(p_fecha, 'DD/MM/YYYY')
            ),
            'registro', NULL
        );
    END IF;

    -- Solo el efectivo exige la caja abierta del día de la venta; transferencia, Yape, Plin, tarjeta
    -- o crédito se pueden registrar en un día con la caja cerrada (su arqueo se recalcula al final).
    -- Desde una venta sin documento no se pide caja: el cobro ya entró con esa venta y la caja
    -- no vuelve a contar el documento derivado (fin_caja_calcular_totales).
    v_mueve_efectivo := NOT v_desde_vsd
        AND ven_pagos_mueven_efectivo(p_pagos, p_id_medio_pago, p_id_condicion_pago);
    IF v_mueve_efectivo THEN
        v_err_caja := fin_caja_assert_abierta(v_fecha_venta, p_id_sucursal);
        IF v_err_caja IS NOT NULL THEN
            IF v_fecha_venta <> p_fecha THEN
                v_err_caja := 'La venta del ' || to_char(v_fecha_venta, 'DD/MM/YYYY')
                    || ' se cobra en efectivo. ' || v_err_caja;
            END IF;
            RETURN json_build_object('error', v_err_caja, 'registro', NULL);
        END IF;
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
        RETURN json_build_object('error', 'El tipo de comprobante indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT lo.descripcion INTO v_codigo_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = p_id_tipo_comprobante;

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
            'La serie electrónica debe tener 4 caracteres (ej. F001, B001, FC01)',
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
            'La nota de crédito/débito debe usar serie que inicie con F o B según el comprobante origen (ej. FC01 / BC01)',
            'registro',
            NULL
        );
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NULL THEN
        RETURN json_build_object('error', 'La nota de crédito/débito requiere el comprobante de origen', 'registro', NULL);
    END IF;

    IF p_id_comprobante_origen IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante_origen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante de origen no existe o está inactivo', 'registro', NULL);
    END IF;

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
                'Solo se puede crear nota de crédito/débito sobre un comprobante ACEPTADO por SUNAT',
                'registro',
                NULL
            );
        END IF;
    END IF;

    v_es_nota_credito := (v_codigo_tipo = '07');

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
                    'Al convertir, el almacén debe ser el mismo de la venta sin documento',
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
            'error', 'Ya existe un comprobante con la serie ' || v_serie || ' y número ' || v_numero,
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
                    || ' no existe o está inactivo',
                'registro',
                NULL
            );
        END IF;

        v_id_balon := NULLIF((v_detalle->>'id_balon')::INTEGER, 0);
        IF v_id_balon IS NOT NULL AND NOT v_es_nota_credito
           AND NOT (
               v_es_conversion_vsd
               AND EXISTS (
                   SELECT 1
                   FROM ven_comprobante_detalle od
                   WHERE od.id_comprobante = p_id_comprobante_origen
                     AND od.estado = 1
                     AND od.id_balon = v_id_balon
               )
           )
        THEN
            SELECT UPPER(TRIM(COALESCE(eb.nombre, '')))
            INTO v_nombre_estado_balon
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE b.id = v_id_balon AND b.estado = 1
            FOR UPDATE OF b;

            IF NOT FOUND THEN
                RETURN json_build_object(
                    'error',
                    format('El cilindro #%s no existe o está inactivo', v_id_balon),
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
                        'El cilindro no está disponible para venta (estado %s)',
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

        IF NOT ven_producto_mueve_kardex_venta(v_id_producto, v_detalle->>'descripcion') THEN
            v_afecta_stock := FALSE;
        END IF;

        IF v_afecta_stock AND NOT v_es_conversion_vsd AND v_codigo_tipo <> '08' THEN
            v_requiere_stock := TRUE;
        END IF;

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

            IF v_id_afectacion_igv IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'Cada detalle debe indicar id_afectacion_igv (no se encontró Gravado 10 en catálogo)',
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
                'Debe indicar el almacén para descontar stock de los productos',
                'registro',
                NULL
            );
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        IF v_es_nota_credito THEN
            SELECT lo.id INTO v_id_tipo_mov_inv
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'INGRESO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_mov_inv IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontró el tipo de movimiento de inventario INGRESO',
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
                    'No se encontró el tipo de movimiento de inventario SALIDA',
                    'registro',
                    NULL
                );
            END IF;
        END IF;

        SELECT lo.nombre INTO v_nombre_tipo_venta
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_venta;

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
                            'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
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
        id_usuario_creacion, id_usuario_modificacion,
        fecha_venta
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
        p_id_usuario_auditoria, p_id_usuario_auditoria,
        -- NULL = la venta es del mismo día de la emisión
        NULLIF(v_fecha_venta, p_fecha)
    )
    RETURNING id INTO v_id;

    v_item := 0;
    v_items_sin_kardex := ARRAY[]::INTEGER[];
    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_item := v_item + 1;

        IF COALESCE((v_detalle->>'no_mueve_kardex')::BOOLEAN, FALSE) THEN
            v_items_sin_kardex := v_items_sin_kardex
                || COALESCE(NULLIF((v_detalle->>'item')::INTEGER, 0), v_item);
        END IF;

        v_id_producto := (v_detalle->>'id_producto')::INTEGER;
        v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
        v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
        v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
        v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);
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
                        'Stock insuficiente del producto % en el almacén (disponible: %, solicitado: %)',
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
                    p_glosa => format('Ajuste conversión %s-%s (+)', v_serie, v_numero),
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
                    p_glosa => format('Ajuste conversión %s-%s (-)', v_serie, v_numero),
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
                    format('Ingreso por nota de crédito %s-%s', v_serie, v_numero)
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

            IF (v_detalle->>'item')::INTEGER = ANY(v_items_sin_kardex) THEN
                CONTINUE;
            END IF;

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
                RAISE EXCEPTION 'No se registró el movimiento de stock (duplicado) para el producto %', v_id_producto;
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
                    'No se puede vender a crédito a Clientes Varios. Selecciona un cliente identificado.';
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
                            'La condición de pago en cuotas requiere día del mes a cobrar (1 a 31).';
                    END IF;

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
                            'CxC en %s cuotas (día %s) %s-%s',
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
                            'No está configurado el tipo de cuenta COBRAR (TipoCuentaFinanciera).';
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
                            'CxC por venta a crédito (%s días) %s-%s',
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

    IF NOT v_es_nota_credito
       AND EXISTS (
           SELECT 1
           FROM ven_comprobante_detalle d
           WHERE d.id_comprobante = v_id
             AND d.estado = 1
             AND d.id_balon IS NOT NULL
             AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
       )
    THEN
        SELECT lo.id INTO v_id_estado_pendiente_envio
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND UPPER(lo.nombre) = 'PENDIENTE_ENVIO' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_pendiente_envio IS NULL THEN
            RAISE EXCEPTION 'Falta el estado PENDIENTE_ENVIO en el catálogo EstadoBalon';
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
              AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
              AND b.id_estado_balon = v_id_estado_disponible;
        END IF;
    END IF;

    v_err_pagos := ven_sincronizar_pagos_comprobante(v_id, p_pagos, p_id_usuario_auditoria);
    IF v_err_pagos IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err_pagos USING ERRCODE = '22023';
    END IF;

    IF NOT v_mueve_efectivo AND NOT v_desde_vsd THEN
        PERFORM fin_caja_refrescar_cerrada(
            v_fecha_venta,
            p_id_sucursal,
            v_total_importe,
            format('Venta %s-%s sin efectivo registrada con la caja cerrada', v_serie, v_numero),
            p_id_usuario_auditoria
        );
    END IF;

    RETURN ven_obtener_comprobante(v_id);
END;
$function$;

-- Completa o corrige los datos de cobro (medio, cuenta, operación) de una venta ya emitida
DROP FUNCTION IF EXISTS public.ven_registrar_cobro_comprobante (
  p_id_comprobante integer,
  p_pagos json,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.ven_registrar_cobro_comprobante (
  p_id_comprobante integer,
  p_pagos json DEFAULT NULL::json,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado VARCHAR;
    v_fecha DATE;
    v_id_sucursal INTEGER;
    v_pago JSON;
    v_id_pago INTEGER;
    v_id_medio INTEGER;
    v_id_cuenta INTEGER;
    v_cambia_medio BOOLEAN;
    v_linea RECORD;
    v_error TEXT;
    v_actualizados INTEGER := 0;
    v_medio_principal INTEGER;
    v_hubo_cambio_medio BOOLEAN := FALSE;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_pagos IS NULL OR json_typeof(p_pagos) <> 'array' THEN
        RETURN json_build_object('error', 'Los cobros deben enviarse como una lista', 'registro', NULL);
    END IF;

    -- La caja del cobro es la del día de la venta (fecha_venta), no la de emisión.
    SELECT UPPER(COALESCE(est.nombre, '')), COALESCE(c.fecha_venta, c.fecha), c.id_sucursal
    INTO v_estado, v_fecha, v_id_sucursal
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
    WHERE c.id = p_id_comprobante AND c.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El comprobante no existe o está inactivo', 'registro', NULL);
    END IF;

    IF v_estado = 'ANULADO' THEN
        RETURN json_build_object(
            'error', 'El comprobante está anulado: no se puede registrar su cobro',
            'registro', NULL
        );
    END IF;

    -- Los errores por línea abortan con RAISE: así no queda un cambio a medias.
    FOR v_pago IN SELECT * FROM json_array_elements(p_pagos)
    LOOP
        v_id_pago := NULLIF(v_pago ->> 'idPago', '')::INTEGER;

        IF v_id_pago IS NULL THEN
            RAISE EXCEPTION '%', 'Falta el identificador de la línea de cobro';
        END IF;

        SELECT * INTO v_linea
        FROM ven_comprobante_pago
        WHERE id = v_id_pago AND id_comprobante = p_id_comprobante AND estado = 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION '%', format('La línea de cobro %s no pertenece a este comprobante', v_id_pago);
        END IF;

        v_id_medio := COALESCE(NULLIF(v_pago ->> 'idMedioPago', '')::INTEGER, v_linea.id_medio_pago);
        v_cambia_medio := v_id_medio IS DISTINCT FROM v_linea.id_medio_pago;

        IF v_cambia_medio THEN
            IF fin_medio_pago_flag(v_id_medio, 'ES_CREDITO') THEN
                RAISE EXCEPTION '%', 'No se puede cambiar el cobro a crédito: la venta ya se registró como contado.';
            END IF;

            v_hubo_cambio_medio := TRUE;

            -- Solo exige la caja abierta si entra o sale efectivo; entre medios sin efectivo
            -- (Yape, Plin, transferencia...) basta recalcular el arqueo si la caja está cerrada.
            IF v_linea.id_medio_pago IS NULL
               OR fin_medio_pago_flag(v_linea.id_medio_pago, 'ES_EFECTIVO')
               OR fin_medio_pago_flag(v_id_medio, 'ES_EFECTIVO') THEN
                v_error := fin_caja_assert_abierta(v_fecha, v_id_sucursal);
                IF v_error IS NOT NULL THEN
                    RAISE EXCEPTION '%', 'El cambio de medio de pago afecta la caja del '
                            || to_char(v_fecha, 'DD/MM/YYYY') || '. ' || v_error;
                END IF;
            END IF;

            -- Con otro medio, la cuenta anterior ya no aplica: se toma solo la enviada.
            v_id_cuenta := NULLIF(v_pago ->> 'idCuentaBancaria', '')::INTEGER;
        ELSE
            v_id_cuenta := COALESCE(
                NULLIF(v_pago ->> 'idCuentaBancaria', '')::INTEGER,
                v_linea.id_cuenta_bancaria
            );
        END IF;

        v_error := fin_validar_cuenta_medio_pago(v_id_medio, v_id_cuenta);
        IF v_error IS NOT NULL THEN
            RAISE EXCEPTION '%', v_error;
        END IF;

        UPDATE ven_comprobante_pago
        SET id_medio_pago = v_id_medio,
            numero_operacion = CASE
                WHEN v_cambia_medio
                    THEN NULLIF(TRIM(COALESCE(v_pago ->> 'numeroOperacion', '')), '')
                ELSE COALESCE(
                    NULLIF(TRIM(COALESCE(v_pago ->> 'numeroOperacion', '')), ''),
                    numero_operacion
                )
            END,
            referencia = COALESCE(
                NULLIF(TRIM(COALESCE(v_pago ->> 'referencia', '')), ''),
                referencia
            ),
            observacion = COALESCE(
                NULLIF(TRIM(COALESCE(v_pago ->> 'observacion', '')), ''),
                observacion
            ),
            id_cuenta_bancaria = v_id_cuenta,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_id_pago;

        v_actualizados := v_actualizados + 1;
    END LOOP;

    IF v_hubo_cambio_medio THEN
        PERFORM fin_caja_refrescar_cerrada(
            v_fecha, v_id_sucursal, NULL,
            'Cambio de medio de pago sin efectivo en el comprobante #' || p_id_comprobante,
            p_id_usuario
        );
    END IF;

    -- El medio de la cabecera es el de la línea de mayor monto (igual que al emitir).
    SELECT id_medio_pago INTO v_medio_principal
    FROM ven_comprobante_pago
    WHERE id_comprobante = p_id_comprobante AND estado = 1
    ORDER BY monto DESC, item ASC
    LIMIT 1;

    UPDATE ven_comprobante
    SET id_medio_pago = COALESCE(v_medio_principal, id_medio_pago),
        id_usuario_modificacion = COALESCE(p_id_usuario, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante
      AND id_medio_pago IS DISTINCT FROM COALESCE(v_medio_principal, id_medio_pago);

    RETURN json_build_object(
        'registro', json_build_object(
            'idComprobante', p_id_comprobante,
            'actualizados', v_actualizados,
            'pagos', (ven_obtener_comprobante(p_id_comprobante)) -> 'pagos'
        )
    );
END;
$function$;

-- Actualiza comprobante
DROP FUNCTION IF EXISTS public.ven_actualizar_comprobante (
  p_id integer,
  p_fecha date,
  p_id_cliente integer,
  p_detalles json,
  p_id_tipo_operacion_sunat integer,
  p_id_comprobante_origen integer,
  p_id_motivo_nota integer,
  p_id_tipo_movimiento integer,
  p_id_tipo_venta integer,
  p_fecha_vencimiento date,
  p_tipo_cambio numeric,
  p_id_sucursal integer,
  p_id_almacen integer,
  p_id_condicion_pago integer,
  p_id_moneda integer,
  p_id_medio_pago integer,
  p_glosa character varying,
  p_observaciones character varying,
  p_periodo_contable character varying,
  p_operacion character varying,
  p_id_estado integer,
  p_cuotas json,
  p_id_usuario_auditoria integer,
  p_origen_pos character varying,
  p_pagos json,
  p_motivo_correccion varchar,
  p_version_esperada varchar
);

-- Firma vigente (con reemplazo de balones). La anterior se elimina arriba: si
-- quedaran ambas, la llamada con 27 argumentos sería ambigua.
DROP FUNCTION IF EXISTS public.ven_actualizar_comprobante (
  p_id integer,
  p_fecha date,
  p_id_cliente integer,
  p_detalles json,
  p_id_tipo_operacion_sunat integer,
  p_id_comprobante_origen integer,
  p_id_motivo_nota integer,
  p_id_tipo_movimiento integer,
  p_id_tipo_venta integer,
  p_fecha_vencimiento date,
  p_tipo_cambio numeric,
  p_id_sucursal integer,
  p_id_almacen integer,
  p_id_condicion_pago integer,
  p_id_moneda integer,
  p_id_medio_pago integer,
  p_glosa character varying,
  p_observaciones character varying,
  p_periodo_contable character varying,
  p_operacion character varying,
  p_id_estado integer,
  p_cuotas json,
  p_id_usuario_auditoria integer,
  p_origen_pos character varying,
  p_pagos json,
  p_motivo_correccion varchar,
  p_version_esperada varchar,
  p_cambios_balon jsonb
);

CREATE OR REPLACE FUNCTION public.ven_actualizar_comprobante (
  p_id integer,
  p_fecha date DEFAULT NULL::date,
  p_id_cliente integer DEFAULT NULL::integer,
  p_detalles json DEFAULT NULL::json,
  p_id_tipo_operacion_sunat integer DEFAULT NULL::integer,
  p_id_comprobante_origen integer DEFAULT NULL::integer,
  p_id_motivo_nota integer DEFAULT NULL::integer,
  p_id_tipo_movimiento integer DEFAULT NULL::integer,
  p_id_tipo_venta integer DEFAULT NULL::integer,
  p_fecha_vencimiento date DEFAULT NULL::date,
  p_tipo_cambio numeric DEFAULT NULL::numeric,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_id_condicion_pago integer DEFAULT NULL::integer,
  p_id_moneda integer DEFAULT NULL::integer,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_glosa character varying DEFAULT NULL::character varying,
  p_observaciones character varying DEFAULT NULL::character varying,
  p_periodo_contable character varying DEFAULT NULL::character varying,
  p_operacion character varying DEFAULT NULL::character varying,
  p_id_estado integer DEFAULT NULL::integer,
  p_cuotas json DEFAULT NULL::json,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_origen_pos character varying DEFAULT NULL::character varying,
  p_pagos json DEFAULT NULL::json,
  p_motivo_correccion varchar DEFAULT NULL,
  p_version_esperada varchar DEFAULT NULL,
  -- [{ "idBalonActual": n, "idBalonNuevo": m }]: reemplazo de cilindros reservados del detalle.
  p_cambios_balon jsonb DEFAULT NULL
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_err_pagos TEXT;
    v_antes JSONB;
    v_edicion_segura BOOLEAN;
    v_dependencias BOOLEAN;
    v_version TEXT;
    v_estado_sunat VARCHAR;
    v_detalle JSON;
    v_cuota JSON;
    v_item INTEGER;
    v_id_producto INTEGER;
    v_cantidad NUMERIC(12,4);
    v_precio_unitario NUMERIC(12,6);
    v_descuento_linea NUMERIC(12,4);
    v_porcentaje_igv NUMERIC(6,4);
    v_valor_linea NUMERIC(12,4);
    v_impuesto_linea NUMERIC(12,4);
    v_importe_linea NUMERIC(12,4);
    v_codigo_afectacion VARCHAR;
    v_descuento_total NUMERIC(12,4) := 0;
    v_valor_venta_total NUMERIC(12,4) := 0;
    v_igv_total NUMERIC(12,4) := 0;
    v_sub_total NUMERIC(12,4) := 0;
    v_total_importe NUMERIC(12,4) := 0;
    v_exonerado_total NUMERIC(12,4) := 0;
    v_id_estado_cuota INTEGER;
    v_numero_cuota INTEGER;
    v_recalcular BOOLEAN := FALSE;
    v_codigo_tipo VARCHAR;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_fecha DATE;
    v_id_almacen_actual INTEGER;
    v_id_almacen_nuevo INTEGER;
    v_id_tipo_venta INTEGER;
    v_es_nota_credito BOOLEAN := FALSE;
    v_mueve_stock BOOLEAN := FALSE;
    v_afecta_stock BOOLEAN;
    v_id_tipo_mov_salida INTEGER;
    v_id_tipo_mov_ingreso INTEGER;
    v_nombre_tipo_venta VARCHAR;
    v_qty_antigua NUMERIC(12,4);
    v_qty_nueva NUMERIC(12,4);
    v_delta_stock NUMERIC(12,4);
    v_stock_disponible NUMERIC(12,4);
    v_mov_result JSON;
    v_id_tipo_mov_aplicar INTEGER;
    v_cantidad_aplicar NUMERIC(12,4);
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
    -- Líneas atadas a balones, gas, alquiler o garantía: solo admiten cambio de precio.
    v_items_bloqueados INTEGER[] := ARRAY[]::INTEGER[];
    v_bloqueadas_antes JSONB;
    v_bloqueadas_nuevas JSONB;
    -- Caja: el arqueo se calcula con las líneas de cobro de la venta.
    v_total_anterior NUMERIC(12,4);
    v_total_nuevo NUMERIC(12,4);
    v_fecha_anterior DATE;
    v_id_sucursal_anterior INTEGER;
    v_id_sucursal_nueva INTEGER;
    v_afecta_caja BOOLEAN;
    v_lineas_pago INTEGER;
    v_fecha_caja DATE;
    v_id_sucursal_caja INTEGER;
    -- Reemplazo de balones
    v_cambio JSONB;
    v_id_balon_actual INTEGER;
    v_id_balon_nuevo INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';
    PERFORM ven_validar_edicion_pre_emision(p_id);
    SELECT xmin::text INTO v_version FROM ven_comprobante WHERE id = p_id AND estado = 1 FOR UPDATE;
    v_antes := ven_obtener_comprobante(p_id)::jsonb;

    SELECT
        es.nombre,
        tc.descripcion,
        c.serie,
        c.numero,
        c.fecha,
        c.id_almacen,
        c.id_tipo_venta
    INTO
        v_estado_sunat,
        v_codigo_tipo,
        v_serie,
        v_numero,
        v_fecha,
        v_id_almacen_actual,
        v_id_tipo_venta
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
    LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
    WHERE c.id = p_id AND c.estado = 1;

    IF v_estado_sunat IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_estado_sunat IN ('ACEPTADO', 'BAJA') THEN
        RETURN json_build_object(
            'error', 'No se puede editar un comprobante con estado SUNAT ' || v_estado_sunat,
            'registro', NULL
        );
    END IF;

    IF v_codigo_tipo IN ('NV', 'VSD') AND EXISTS (
        SELECT 1
        FROM ven_comprobante
        WHERE id_comprobante_origen = p_id
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'No se puede editar una venta sin documento que ya fue convertida a boleta/factura',
            'registro',
            NULL
        );
    END IF;

    v_edicion_segura := v_codigo_tipo IN ('NV', 'VSD', '01', '03');
    v_dependencias := EXISTS (SELECT 1 FROM ven_comprobante_detalle WHERE id_comprobante = p_id AND estado = 1 AND (id_balon IS NOT NULL OR COALESCE(descripcion,'') ~* 'garant[ií]a'))
        OR EXISTS (SELECT 1 FROM bal_prestamo WHERE id_comprobante_venta = p_id AND estado = 1)
        OR EXISTS (SELECT 1 FROM bal_movimiento_recarga WHERE id_comprobante = p_id AND estado = 1)
        OR EXISTS (SELECT 1 FROM bal_alquiler WHERE id_comprobante_venta = p_id AND estado = 1)
        OR EXISTS (SELECT 1 FROM ven_vsd_operacion WHERE id_comprobante = p_id AND tipo = 'CAMBIO_BALON')
        OR EXISTS (SELECT 1 FROM doc_salida WHERE id_venta = p_id AND estado = 1);
    IF v_edicion_segura THEN
        IF p_id_usuario_auditoria IS NULL OR length(btrim(COALESCE(p_motivo_correccion, ''))) < 5 THEN
            RAISE EXCEPTION 'Indique el motivo de la corrección (mínimo 5 caracteres) y el usuario';
        END IF;
        IF p_version_esperada IS NULL OR p_version_esperada <> v_version THEN
            RAISE EXCEPTION 'La venta cambió desde que se abrió. Recargue y revise los datos';
        END IF;
        IF p_id_comprobante_origen IS NOT NULL OR p_id_tipo_venta IS NOT NULL OR p_id_estado IS NOT NULL THEN
            RAISE EXCEPTION 'No se puede cambiar el origen, tipo o estado de una venta mediante corrección';
        END IF;
    END IF;

    -- ---- Reemplazo de balones del detalle ----
    -- Se aplica antes de validar el detalle: las líneas que llegan ya traen el
    -- balón nuevo. Cada cambio es una corrección (ven_cambiar_balon_vsd) que no mueve gas:
    -- el anterior vuelve a DISPONIBLE y el nuevo toma su lugar.
    --   * PENDIENTE_ENVIO (reservado para despacho) → CORRECCION_RESERVA.
    --   * Ya con el cliente (mostrador: EN_PODER_CLIENTE / PRESTADO_CLIENTE) →
    --     CORRECCION_REGISTRO: se registró otro código; el préstamo pasa al correcto.
    IF p_cambios_balon IS NOT NULL AND jsonb_typeof(p_cambios_balon) = 'array'
       AND jsonb_array_length(p_cambios_balon) > 0 THEN
        IF NOT v_edicion_segura THEN
            RAISE EXCEPTION 'Solo se pueden reemplazar balones en ventas, facturas o boletas';
        END IF;
        IF (SELECT count(*) FROM jsonb_array_elements(p_cambios_balon) e) <>
           (SELECT count(DISTINCT (e->>'idBalonActual')::integer) FROM jsonb_array_elements(p_cambios_balon) e)
           OR (SELECT count(*) FROM jsonb_array_elements(p_cambios_balon) e) <>
           (SELECT count(DISTINCT (e->>'idBalonNuevo')::integer) FROM jsonb_array_elements(p_cambios_balon) e) THEN
            RAISE EXCEPTION 'Cada balón solo puede reemplazarse una vez y por un cilindro distinto en la misma corrección';
        END IF;

        FOR v_cambio IN SELECT e FROM jsonb_array_elements(p_cambios_balon) e
        LOOP
            v_id_balon_actual := NULLIF(v_cambio->>'idBalonActual', '')::integer;
            v_id_balon_nuevo := NULLIF(v_cambio->>'idBalonNuevo', '')::integer;

            IF v_id_balon_actual IS NULL OR v_id_balon_nuevo IS NULL OR v_id_balon_actual = v_id_balon_nuevo THEN
                RAISE EXCEPTION 'Indique el balón a reemplazar y uno distinto como reemplazo';
            END IF;
            IF NOT EXISTS (SELECT 1 FROM ven_comprobante_detalle
                WHERE id_comprobante = p_id AND estado = 1 AND id_balon = v_id_balon_actual) THEN
                RAISE EXCEPTION 'El balón % no está en el detalle de esta venta', COALESCE(
                    (SELECT codigo_balon FROM bal_balon WHERE id = v_id_balon_actual), '#' || v_id_balon_actual);
            END IF;
            -- Sin despacho asignado: ni en una orden de salida en borrador o con reparto
            -- pendiente (ven_cambiar_balon_vsd ya revisa actividades pendientes).
            IF EXISTS (
                SELECT 1
                FROM doc_salida_detalle dd
                JOIN doc_salida d ON d.id = dd.id_doc_salida AND d.estado = 1
                JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
                WHERE dd.id_balon = v_id_balon_nuevo AND dd.estado = 1
                  AND ec.nombre <> 'ANULADA'
                  AND (ec.nombre = 'BORRADOR' OR EXISTS (
                      SELECT 1 FROM age_actividad a
                      JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
                      WHERE a.id_doc_salida = d.id AND a.estado = 1
                        AND ea.nombre NOT IN ('REALIZADA', 'CANCELADA')))
            ) THEN
                RAISE EXCEPTION 'El balón % ya está asignado a un despacho pendiente', COALESCE(
                    (SELECT codigo_balon FROM bal_balon WHERE id = v_id_balon_nuevo), '#' || v_id_balon_nuevo);
            END IF;

            PERFORM ven_cambiar_balon_vsd(p_id, jsonb_build_object(
                'tipoOperacion', CASE WHEN (
                    SELECT eb.nombre FROM bal_balon b
                    JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
                    WHERE b.id = v_id_balon_actual
                ) = 'PENDIENTE_ENVIO' THEN 'CORRECCION_RESERVA' ELSE 'CORRECCION_REGISTRO' END,
                'solicitud', gen_random_uuid(),
                'versionEsperada', (SELECT xmin::text FROM ven_comprobante WHERE id = p_id),
                'idBalonActual', v_id_balon_actual,
                'idBalonNuevo', v_id_balon_nuevo,
                'idAlmacen', v_id_almacen_actual,
                'cantidadGasDevuelta', 0,
                'cantidadGasSalida', 0,
                'condicionDevolucion', 'DISPONIBLE',
                'motivo', btrim(p_motivo_correccion)
            ), p_id_usuario_auditoria);
        END LOOP;
    END IF;
    -- Ítems: una línea que trae el ítem de una línea vigente lo conserva; las nuevas
    -- (o un ítem repetido) toman uno libre después del mayor usado en el comprobante.
    IF p_detalles IS NOT NULL AND json_typeof(p_detalles) = 'array' THEN
        SELECT json_agg(x.v ORDER BY x.o) INTO p_detalles
        FROM (
            SELECT k.o, jsonb_set(k.v, '{item}', to_jsonb(CASE WHEN k.conserva THEN k.it
                ELSE m.max_item + row_number() OVER (PARTITION BY k.conserva ORDER BY k.o) END)) AS v
            FROM (
                SELECT j.o, j.v, j.it,
                    (j.it IS NOT NULL
                     AND EXISTS (SELECT 1 FROM ven_comprobante_detalle d
                         WHERE d.id_comprobante = p_id AND d.estado = 1 AND d.item = j.it)
                     AND row_number() OVER (PARTITION BY j.it ORDER BY j.o) = 1) AS conserva
                FROM (
                    SELECT e.value::jsonb AS v, e.ordinality AS o,
                        NULLIF(e.value->>'item', '')::integer AS it
                    FROM json_array_elements(p_detalles) WITH ORDINALITY e(value, ordinality)
                ) j
            ) k
            CROSS JOIN (SELECT COALESCE(MAX(item), 0) AS max_item
                FROM ven_comprobante_detalle WHERE id_comprobante = p_id) m
        ) x;
    END IF;

    IF v_dependencias THEN
        SELECT COALESCE(array_agg(d.item), ARRAY[]::INTEGER[]) INTO v_items_bloqueados
        FROM ven_comprobante_detalle d
        LEFT JOIN pro_producto p ON p.id = d.id_producto
        WHERE d.id_comprobante = p_id AND d.estado = 1
          AND (d.id_balon IS NOT NULL
               OR COALESCE(d.descripcion, '') ~* 'garant[ií]a'
               OR COALESCE(p.es_gas, FALSE)
               OR COALESCE(p.es_alquilable, FALSE));
    END IF;

    IF v_dependencias AND p_detalles IS NOT NULL THEN
        SELECT jsonb_agg(jsonb_build_array(d.item, d.id_producto, d.cantidad, d.id_balon,
                 d.id_unidad_medida, d.capacidad_cilindro, d.id_estado_cilindro,
                 COALESCE(d.descripcion, '')) ORDER BY d.item)
        INTO v_bloqueadas_antes
        FROM ven_comprobante_detalle d
        WHERE d.id_comprobante = p_id AND d.estado = 1 AND d.item = ANY(v_items_bloqueados);

        SELECT jsonb_agg(jsonb_build_array((j.value->>'item')::integer,
                 (j.value->>'id_producto')::integer, (j.value->>'cantidad')::numeric,
                 NULLIF((j.value->>'id_balon')::integer, 0), NULLIF((j.value->>'id_unidad_medida')::integer, 0),
                 NULLIF((j.value->>'capacidad_cilindro')::numeric, 0), NULLIF((j.value->>'id_estado_cilindro')::integer, 0),
                 COALESCE(j.value->>'descripcion', '')) ORDER BY (j.value->>'item')::integer)
        INTO v_bloqueadas_nuevas
        FROM json_array_elements(p_detalles) j
        WHERE (j.value->>'item')::integer = ANY(v_items_bloqueados);

        IF v_bloqueadas_antes IS DISTINCT FROM v_bloqueadas_nuevas THEN
            RAISE EXCEPTION 'Las líneas con balón, gas, alquiler o garantía vinculados no se pueden quitar ni cambiar de producto o cantidad. Use Cambio de balón para el movimiento físico; sí puede corregir su precio y agregar o editar los demás productos';
        END IF;

        IF EXISTS (SELECT 1 FROM json_array_elements(p_detalles) j
            WHERE NOT ((j.value->>'item')::integer = ANY(v_items_bloqueados))
              AND (NULLIF((j.value->>'id_balon')::integer, 0) IS NOT NULL
                   OR COALESCE((j.value->>'no_mueve_kardex')::boolean, false))) THEN
            RAISE EXCEPTION 'La corrección de productos no puede crear una salida de balón ni omitir el kardex';
        END IF;
    END IF;

    IF v_dependencias AND (
        (p_id_cliente IS NOT NULL AND p_id_cliente IS DISTINCT FROM (v_antes->'registro'->>'id_cliente')::integer)
        OR (p_id_almacen IS NOT NULL AND p_id_almacen IS DISTINCT FROM v_id_almacen_actual)) THEN
        RAISE EXCEPTION 'La venta tiene balones, préstamos, recargas u órdenes vinculadas; la corrección conserva el cliente y el almacén';
    END IF;
    IF p_detalles IS NOT NULL THEN
        IF json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
            RAISE EXCEPTION 'Debe registrar al menos un detalle';
        END IF;
        PERFORM id FROM pro_producto WHERE id IN (SELECT (value->>'id_producto')::integer FROM json_array_elements(p_detalles)) ORDER BY id FOR SHARE;
        IF EXISTS (SELECT 1 FROM json_array_elements(p_detalles) WITH ORDINALITY j(value,ordinality)
            GROUP BY COALESCE(NULLIF((j.value->>'item')::integer,0),j.ordinality::integer) HAVING count(*)>1) THEN
            RAISE EXCEPTION 'Los ítems del detalle no pueden estar duplicados';
        END IF;
        IF EXISTS (SELECT 1 FROM json_array_elements(p_detalles) j
            LEFT JOIN pro_producto p ON p.id = (j.value->>'id_producto')::integer AND p.estado = 1
            WHERE p.id IS NULL OR (j.value->>'cantidad')::numeric <= 0
                OR COALESCE((j.value->>'precio_unitario')::numeric, -1) < 0
                OR COALESCE((j.value->>'descuento')::numeric, 0) < 0
                OR COALESCE((j.value->>'porcentaje_igv')::numeric, 18) NOT BETWEEN 0 AND 100
                OR COALESCE((j.value->>'descuento')::numeric, 0) > (j.value->>'cantidad')::numeric * (j.value->>'precio_unitario')::numeric) THEN
            RAISE EXCEPTION 'Detalle inválido: producto inactivo, cantidad, precio o descuento incorrectos';
        END IF;
        IF NOT v_dependencias AND EXISTS (SELECT 1 FROM json_array_elements(p_detalles) j
            WHERE NULLIF((j.value->>'id_balon')::integer, 0) IS NOT NULL
               OR COALESCE((j.value->>'no_mueve_kardex')::boolean, false)) THEN
            RAISE EXCEPTION 'La corrección de productos no puede crear una salida de balón ni omitir el kardex';
        END IF;
        IF EXISTS (SELECT 1 FROM json_array_elements(p_detalles) WITH ORDINALITY j(value,ordinality)
            JOIN ven_comprobante_detalle d ON d.id_comprobante=p_id AND d.estado=1
                AND d.item=COALESCE(NULLIF((j.value->>'item')::integer,0),j.ordinality::integer)
            WHERE COALESCE(d.descripcion,'') ~* 'garant[ií]a' AND
                jsonb_build_array(d.precio_unitario,COALESCE(d.descuento,0),d.porcentaje_igv,d.id_afectacion_igv)
                IS DISTINCT FROM jsonb_build_array((j.value->>'precio_unitario')::numeric,
                    COALESCE((j.value->>'descuento')::numeric,0),COALESCE((j.value->>'porcentaje_igv')::numeric,18),
                    NULLIF((j.value->>'id_afectacion_igv')::integer,0))) THEN
            RAISE EXCEPTION 'Los importes de garantía deben corregirse desde el módulo de garantías';
        END IF;
    END IF;
    IF fin_cuenta_documento_tiene_pagos(p_id,NULL) AND (
        p_cuotas IS NOT NULL OR p_id_condicion_pago IS NOT NULL OR p_id_moneda IS NOT NULL
        OR (p_id_cliente IS NOT NULL AND p_id_cliente IS DISTINCT FROM (v_antes->'registro'->>'id_cliente')::integer)) THEN
        RAISE EXCEPTION 'La cuenta por cobrar tiene pagos; no se pueden reasignar cliente, moneda, condición o cuotas desde la corrección';
    END IF;

    IF p_id_cliente IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_es_nota_credito := (v_codigo_tipo = '07');
    v_mueve_stock := (v_codigo_tipo IN ('01', '03', '07', 'NV', 'VSD'));
    v_id_almacen_nuevo := COALESCE(p_id_almacen, v_id_almacen_actual);
    v_fecha := COALESCE(p_fecha, v_fecha);
    v_id_tipo_venta := COALESCE(p_id_tipo_venta, v_id_tipo_venta);

    IF p_detalles IS NOT NULL THEN
        IF json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
            RETURN json_build_object('error', 'Debe registrar al menos un detalle', 'registro', NULL);
        END IF;

        v_recalcular := TRUE;

        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_id_producto := NULLIF((v_detalle->>'id_producto')::INTEGER, 0);
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
            v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
            v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
            v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);

            IF v_id_producto IS NULL OR v_cantidad <= 0 THEN
                RETURN json_build_object('error', 'Detalle inválido: producto y cantidad son obligatorios', 'registro', NULL);
            END IF;

            SELECT
                REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
                COALESCE(p.es_gas, FALSE)
            INTO v_nombre_unidad, v_es_gas
            FROM pro_producto p
            LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
            WHERE p.id = v_id_producto;

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

            v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);

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
    END IF;

    IF v_mueve_stock AND (p_detalles IS NOT NULL OR p_id_almacen IS NOT NULL) THEN
        IF EXISTS (
            SELECT 1
            FROM ven_comprobante_detalle d
            INNER JOIN pro_producto p ON p.id = d.id_producto
            WHERE d.id_comprobante = p_id
              AND d.estado = 1
              AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
        ) OR (
            p_detalles IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM json_array_elements(p_detalles) j
                INNER JOIN pro_producto p ON p.id = (j.value->>'id_producto')::INTEGER
                WHERE ven_producto_mueve_kardex_venta(p.id, j.value->>'descripcion')
            )
        ) THEN
            IF v_id_almacen_nuevo IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'Debe indicar el almacén para ajustar stock de los productos',
                    'registro',
                    NULL
                );
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_nuevo AND estado = 1
            ) THEN
                RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
            END IF;

            SELECT lo.id INTO v_id_tipo_mov_salida
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'SALIDA' AND lo.estado = 1
            LIMIT 1;

            SELECT lo.id INTO v_id_tipo_mov_ingreso
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'INGRESO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_mov_salida IS NULL OR v_id_tipo_mov_ingreso IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontraron tipos de movimiento SALIDA/INGRESO',
                    'registro',
                    NULL
                );
            END IF;

            SELECT lo.nombre INTO v_nombre_tipo_venta
            FROM gen_lista_opciones lo
            WHERE lo.id = v_id_tipo_venta;

            IF p_detalles IS NULL THEN
                IF v_id_almacen_actual IS DISTINCT FROM v_id_almacen_nuevo THEN
                    FOR v_id_producto, v_qty_antigua IN
                        SELECT d.id_producto, SUM(d.cantidad)
                        FROM ven_comprobante_detalle d
                        INNER JOIN pro_producto p ON p.id = d.id_producto
                        WHERE d.id_comprobante = p_id
                          AND d.estado = 1
                          AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                        GROUP BY d.id_producto
                    LOOP
                        IF v_es_nota_credito THEN
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                        END IF;

                        v_mov_result := inv_registrar_movimiento(
                            'PRODUCTO',
                            CASE WHEN v_es_nota_credito THEN 'SALIDA' ELSE 'INGRESO' END,
                            v_fecha,
                            v_id_producto,
                            NULL,
                            v_qty_antigua,
                            v_id_almacen_actual,
                            NULL,
                            NULL,
                            ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                            p_id,
                            format('Cambio almacén %s-%s (revertir)', v_serie, v_numero),
                            p_id_usuario_auditoria,
                            NULL,
                            NULL,
                            TRUE
                        );
                        IF v_mov_result->>'error' IS NOT NULL THEN
                            RAISE EXCEPTION '%', v_mov_result->>'error';
                        END IF;

                        IF v_es_nota_credito THEN
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                        ELSE
                            SELECT COALESCE(s.stock, 0)
                            INTO v_stock_disponible
                            FROM pro_stock s
                            WHERE s.id_almacen = v_id_almacen_nuevo
                              AND s.id_producto = v_id_producto
                              AND s.estado = 1;

                            IF COALESCE(v_stock_disponible, 0) < v_qty_antigua THEN
                                RAISE EXCEPTION '%', format(
                                        'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                        COALESCE(v_stock_disponible, 0),
                                        v_qty_antigua
                                    );
                            END IF;
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                        END IF;

                        v_mov_result := inv_registrar_movimiento(
                            'PRODUCTO',
                            CASE WHEN v_es_nota_credito THEN 'INGRESO' ELSE 'SALIDA' END,
                            v_fecha,
                            v_id_producto,
                            NULL,
                            v_qty_antigua,
                            v_id_almacen_nuevo,
                            NULL,
                            NULL,
                            ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                            p_id,
                            format('Cambio almacén %s-%s (aplicar)', v_serie, v_numero),
                            p_id_usuario_auditoria,
                            NULL,
                            NULL,
                            TRUE
                        );
                        IF v_mov_result->>'error' IS NOT NULL THEN
                            RAISE EXCEPTION '%', v_mov_result->>'error';
                        END IF;
                    END LOOP;
                END IF;
            ELSIF v_id_almacen_actual IS DISTINCT FROM v_id_almacen_nuevo THEN
                FOR v_id_producto, v_qty_antigua IN
                    SELECT d.id_producto, SUM(d.cantidad)
                    FROM ven_comprobante_detalle d
                    INNER JOIN pro_producto p ON p.id = d.id_producto
                    WHERE d.id_comprobante = p_id
                      AND d.estado = 1
                      AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                    GROUP BY d.id_producto
                LOOP
                    IF v_es_nota_credito THEN
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                    ELSE
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_es_nota_credito THEN 'SALIDA' ELSE 'INGRESO' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_qty_antigua,
                        v_id_almacen_actual,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Cambio almacén %s-%s (revertir)', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_mov_result->>'error';
                    END IF;
                END LOOP;

                FOR v_id_producto, v_qty_nueva IN
                    SELECT
                        (value->>'id_producto')::INTEGER,
                        SUM(COALESCE((value->>'cantidad')::NUMERIC, 0))
                    FROM json_array_elements(p_detalles)
                    GROUP BY (value->>'id_producto')::INTEGER
                LOOP
                    IF NOT ven_producto_mueve_kardex_venta(v_id_producto, NULL) THEN
                        CONTINUE;
                    END IF;

                    IF v_es_nota_credito THEN
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                    ELSE
                        SELECT COALESCE(s.stock, 0)
                        INTO v_stock_disponible
                        FROM pro_stock s
                        WHERE s.id_almacen = v_id_almacen_nuevo
                          AND s.id_producto = v_id_producto
                          AND s.estado = 1;

                        IF COALESCE(v_stock_disponible, 0) < v_qty_nueva THEN
                            RAISE EXCEPTION '%', format(
                                    'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                    COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                    COALESCE(v_stock_disponible, 0),
                                    v_qty_nueva
                                );
                        END IF;
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_es_nota_credito THEN 'INGRESO' ELSE 'SALIDA' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_qty_nueva,
                        v_id_almacen_nuevo,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Ajuste edición %s-%s', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_mov_result->>'error';
                    END IF;
                END LOOP;
            ELSE
                FOR v_id_producto, v_qty_antigua, v_qty_nueva IN
                    SELECT
                        COALESCE(o.id_producto, n.id_producto),
                        COALESCE(o.cantidad, 0),
                        COALESCE(n.cantidad, 0)
                    FROM (
                        SELECT d.id_producto, SUM(d.cantidad) AS cantidad
                        FROM ven_comprobante_detalle d
                        INNER JOIN pro_producto p ON p.id = d.id_producto
                        WHERE d.id_comprobante = p_id
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
                    v_delta_stock := v_qty_nueva - v_qty_antigua;
                    IF v_delta_stock = 0 THEN
                        CONTINUE;
                    END IF;

                    IF v_es_nota_credito THEN
                        IF v_delta_stock > 0 THEN
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                            v_cantidad_aplicar := v_delta_stock;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                            v_cantidad_aplicar := ABS(v_delta_stock);
                        END IF;
                    ELSE
                        IF v_delta_stock > 0 THEN
                            SELECT COALESCE(s.stock, 0)
                            INTO v_stock_disponible
                            FROM pro_stock s
                            WHERE s.id_almacen = v_id_almacen_nuevo
                              AND s.id_producto = v_id_producto
                              AND s.estado = 1;

                            IF COALESCE(v_stock_disponible, 0) < v_delta_stock THEN
                                RAISE EXCEPTION '%', format(
                                        'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                        COALESCE(v_stock_disponible, 0),
                                        v_delta_stock
                                    );
                            END IF;
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                            v_cantidad_aplicar := v_delta_stock;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                            v_cantidad_aplicar := ABS(v_delta_stock);
                        END IF;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_id_tipo_mov_aplicar = v_id_tipo_mov_salida THEN 'SALIDA' ELSE 'INGRESO' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_cantidad_aplicar,
                        v_id_almacen_nuevo,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Ajuste edición %s-%s', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_mov_result->>'error';
                    END IF;
                END LOOP;
            END IF;
        END IF;
    END IF;

    UPDATE ven_comprobante
    SET
        fecha = COALESCE(p_fecha, fecha),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_tipo_operacion_sunat = COALESCE(p_id_tipo_operacion_sunat, id_tipo_operacion_sunat),
        id_comprobante_origen = COALESCE(p_id_comprobante_origen, id_comprobante_origen),
        id_motivo_nota = COALESCE(p_id_motivo_nota, id_motivo_nota),
        id_tipo_movimiento = COALESCE(p_id_tipo_movimiento, id_tipo_movimiento),
        id_tipo_venta = COALESCE(p_id_tipo_venta, id_tipo_venta),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        tipo_cambio = COALESCE(p_tipo_cambio, tipo_cambio),
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_condicion_pago = COALESCE(p_id_condicion_pago, id_condicion_pago),
        id_moneda = COALESCE(p_id_moneda, id_moneda),
        id_medio_pago = COALESCE(p_id_medio_pago, id_medio_pago),
        sub_total = CASE WHEN v_recalcular THEN v_sub_total ELSE sub_total END,
        descuento = CASE WHEN v_recalcular THEN v_descuento_total ELSE descuento END,
        valor_venta = CASE WHEN v_recalcular THEN v_valor_venta_total ELSE valor_venta END,
        igv = CASE WHEN v_recalcular THEN v_igv_total ELSE igv END,
        total_importe = CASE WHEN v_recalcular THEN v_total_importe ELSE total_importe END,
        exonerado = CASE WHEN v_recalcular THEN v_exonerado_total ELSE exonerado END,
        glosa = COALESCE(p_glosa, glosa),
        observaciones = COALESCE(p_observaciones, observaciones),
        periodo_contable = COALESCE(p_periodo_contable, periodo_contable),
        operacion = COALESCE(p_operacion, operacion),
        origen_pos = COALESCE(NULLIF(TRIM(p_origen_pos), ''), origen_pos),
        id_estado = COALESCE(p_id_estado, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF p_detalles IS NOT NULL THEN
        -- Las líneas vinculadas se conservan (solo se actualiza su precio); el resto se reemplaza.
        UPDATE ven_comprobante_detalle
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_comprobante = p_id AND estado = 1
          AND NOT (item = ANY(v_items_bloqueados));
        v_item := 0;
        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_item := v_item + 1;
            v_id_producto := (v_detalle->>'id_producto')::INTEGER;
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
            v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
            v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
            v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);
            v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);

            IF v_codigo_afectacion = '10' THEN
                v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
                v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
            ELSE
                v_valor_linea := v_importe_linea;
                v_impuesto_linea := 0;
            END IF;

            IF COALESCE(NULLIF((v_detalle->>'item')::integer, 0), v_item) = ANY(v_items_bloqueados) THEN
                UPDATE ven_comprobante_detalle SET
                    precio_unitario = v_precio_unitario, descuento = v_descuento_linea,
                    valor_venta = v_valor_linea, porcentaje_igv = v_porcentaje_igv,
                    id_afectacion_igv = NULLIF((v_detalle->>'id_afectacion_igv')::integer, 0),
                    impuesto = v_impuesto_linea, importe = v_importe_linea,
                    id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = now()
                WHERE id_comprobante = p_id AND estado = 1
                  AND item = COALESCE(NULLIF((v_detalle->>'item')::integer, 0), v_item);
                CONTINUE;
            END IF;
            INSERT INTO ven_comprobante_detalle (
                id_comprobante, item, id_producto, descripcion, id_unidad_medida,
                cantidad, precio_unitario, descuento, valor_venta, porcentaje_igv,
                id_afectacion_igv, impuesto, importe,
                id_balon, capacidad_cilindro, id_estado_cilindro,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                p_id,
                COALESCE(NULLIF((v_detalle->>'item')::INTEGER, 0), v_item),
                v_id_producto,
                NULLIF(v_detalle->>'descripcion', ''),
                NULLIF((v_detalle->>'id_unidad_medida')::INTEGER, 0),
                v_cantidad,
                v_precio_unitario,
                v_descuento_linea,
                v_valor_linea,
                v_porcentaje_igv,
                NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0),
                v_impuesto_linea,
                v_importe_linea,
                NULLIF((v_detalle->>'id_balon')::INTEGER, 0),
                NULLIF((v_detalle->>'capacidad_cilindro')::NUMERIC, 0),
                NULLIF((v_detalle->>'id_estado_cilindro')::INTEGER, 0),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    IF p_cuotas IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_cuota
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoCuota' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
        LIMIT 1;

        UPDATE ven_cuotas
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_comprobante = p_id AND estado = 1;

        IF json_typeof(p_cuotas) = 'array' THEN
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
                    p_id,
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
    END IF;

    -- ---- Caja ----
    -- La caja del día no guarda copia de la venta: suma en vivo sus líneas de cobro
    -- (ven_comprobante_pago) o, si no tiene, el total de la cabecera. Si cambia el
    -- importe, la fecha o la sucursal, el arqueo de la(s) caja(s) afectada(s) cambia:
    -- no se permite si alguna ya está cerrada, y las líneas de cobro se ajustan al total.
    v_total_anterior := ROUND(COALESCE((v_antes->'registro'->>'total_importe')::NUMERIC, 0), 4);
    -- La caja de una venta es la de su fecha de venta (fecha_venta), o la de emisión si no tiene.
    v_fecha_anterior := COALESCE(
        (v_antes->'registro'->>'fecha_caja')::DATE,
        (v_antes->'registro'->>'fecha_venta')::DATE,
        (v_antes->'registro'->>'fecha')::DATE
    );
    v_id_sucursal_anterior := NULLIF(v_antes->'registro'->>'id_sucursal', '')::INTEGER;
    SELECT ROUND(COALESCE(c.total_importe, 0), 4), COALESCE(c.fecha_venta, c.fecha), c.id_sucursal
    INTO v_total_nuevo, v_fecha, v_id_sucursal_nueva
    FROM ven_comprobante c WHERE c.id = p_id;

    IF v_total_nuevo IS DISTINCT FROM v_total_anterior
       OR v_fecha IS DISTINCT FROM v_fecha_anterior
       OR v_id_sucursal_nueva IS DISTINCT FROM v_id_sucursal_anterior
       OR p_pagos IS NOT NULL THEN

        -- Solo el efectivo (antes o después de la corrección) exige que las cajas no estén cerradas;
        -- sin efectivo se corrige igual y se recalcula el arqueo de las cajas cerradas al final.
        SELECT EXISTS (
            SELECT 1 FROM ven_pagos_de_comprobante(p_id) pg
            WHERE pg.id_medio_pago IS NULL OR fin_medio_pago_flag(pg.id_medio_pago, 'ES_EFECTIVO')
        ) OR (p_pagos IS NOT NULL AND json_typeof(p_pagos) = 'array' AND EXISTS (
            SELECT 1 FROM json_array_elements(p_pagos) j
            WHERE NULLIF(j.value->>'idMedioPago', '') IS NULL
               OR fin_medio_pago_flag((j.value->>'idMedioPago')::INTEGER, 'ES_EFECTIVO')
        ))
        INTO v_afecta_caja;

        IF v_afecta_caja THEN
            FOR v_fecha_caja, v_id_sucursal_caja IN
                SELECT DISTINCT f.fecha, f.id_sucursal
                FROM (VALUES (v_fecha_anterior, v_id_sucursal_anterior), (v_fecha, v_id_sucursal_nueva)) f(fecha, id_sucursal)
                WHERE f.fecha IS NOT NULL
            LOOP
                IF EXISTS (
                    SELECT 1
                    FROM fin_caja_sesion s
                    INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
                    WHERE s.estado = 1
                      AND s.fecha = v_fecha_caja
                      AND COALESCE(s.id_sucursal, 0) = COALESCE(v_id_sucursal_caja, 0)
                      AND UPPER(est.nombre) = 'CERRADA'
                ) THEN
                    RAISE EXCEPTION 'La caja del % ya está cerrada y esta corrección cambia su arqueo (total % → %). Reabra la caja de esa fecha para corregir la venta',
                        to_char(v_fecha_caja, 'DD/MM/YYYY'),
                        gen_formato_cantidad(v_total_anterior),
                        gen_formato_cantidad(v_total_nuevo);
                END IF;
            END LOOP;
        END IF;

        -- Sin pagos explícitos: un cobro de un solo medio sigue al nuevo total;
        -- con varios medios hay que indicar cómo se reparte.
        IF p_pagos IS NULL AND v_total_nuevo IS DISTINCT FROM v_total_anterior THEN
            SELECT COUNT(*) INTO v_lineas_pago
            FROM ven_comprobante_pago WHERE id_comprobante = p_id AND estado = 1;

            IF v_lineas_pago = 1 THEN
                IF v_total_nuevo > 0 THEN
                    UPDATE ven_comprobante_pago
                    SET monto = v_total_nuevo,
                        id_usuario_modificacion = p_id_usuario_auditoria,
                        fecha_modificacion = NOW()
                    WHERE id_comprobante = p_id AND estado = 1;
                ELSE
                    DELETE FROM ven_comprobante_pago WHERE id_comprobante = p_id;
                END IF;
            ELSIF v_lineas_pago > 1 THEN
                RAISE EXCEPTION 'La venta se cobró con varios medios de pago y el total cambia de % a %. Indique cómo se reparte el nuevo total entre los medios de pago',
                    gen_formato_cantidad(v_total_anterior),
                    gen_formato_cantidad(v_total_nuevo)
                    USING ERRCODE = '22023';
            END IF;
        END IF;
    END IF;

    IF NOT v_es_nota_credito THEN
        PERFORM ven_sincronizar_cxc_venta(p_id, p_id_usuario_auditoria);
    END IF;

    v_err_pagos := ven_sincronizar_pagos_comprobante(p_id, p_pagos, p_id_usuario_auditoria);
    IF v_err_pagos IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err_pagos USING ERRCODE = '22023';
    END IF;

    IF v_afecta_caja IS NOT NULL AND NOT v_afecta_caja THEN
        FOR v_fecha_caja, v_id_sucursal_caja IN
            SELECT DISTINCT f.fecha, f.id_sucursal
            FROM (VALUES (v_fecha_anterior, v_id_sucursal_anterior), (v_fecha, v_id_sucursal_nueva)) f(fecha, id_sucursal)
            WHERE f.fecha IS NOT NULL
        LOOP
            PERFORM fin_caja_refrescar_cerrada(
                v_fecha_caja, v_id_sucursal_caja, v_total_nuevo,
                'Corrección sin efectivo del comprobante #' || p_id,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    IF v_edicion_segura THEN
        INSERT INTO ven_vsd_operacion(id_comprobante, tipo, motivo, datos, anterior, posterior, id_usuario)
        VALUES (p_id, 'CORRECCION', btrim(p_motivo_correccion),
            jsonb_build_object('version', p_version_esperada), v_antes,
            ven_obtener_comprobante(p_id)::jsonb, p_id_usuario_auditoria);
    END IF;
    RETURN ven_obtener_comprobante(p_id);
END;
$function$;

COMMIT;
