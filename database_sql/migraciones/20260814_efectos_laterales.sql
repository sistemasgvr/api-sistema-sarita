-- Efectos colaterales: stock, CxC/CxP, cilindros, GRE, caja, traslado
ALTER TABLE pro_movimientos
  ADD COLUMN IF NOT EXISTS id_almacen_destino INT REFERENCES gen_almacen(id);

-- ===== database_sql/funciones/comprobantes/ven_producto_mueve_kardex_venta.sql =====
-- Kardex de venta: solo accesorios/gases vendidos.
-- No mueve stock la tarifa de alquiler (es_alquilable) ni líneas de garantía.
CREATE OR REPLACE FUNCTION ven_producto_mueve_kardex_venta(
    p_id_producto INTEGER,
    p_descripcion VARCHAR DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_afecta BOOLEAN;
    v_servicio BOOLEAN;
    v_alquilable BOOLEAN;
BEGIN
    IF p_id_producto IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT
        COALESCE(p.afecta_stock, FALSE),
        COALESCE(p.es_servicio, FALSE),
        COALESCE(p.es_alquilable, FALSE)
    INTO v_afecta, v_servicio, v_alquilable
    FROM pro_producto p
    WHERE p.id = p_id_producto;

    IF NOT FOUND OR NOT v_afecta OR v_servicio OR v_alquilable THEN
        RETURN FALSE;
    END IF;

    IF p_descripcion IS NOT NULL AND BTRIM(p_descripcion) ~* 'garant[ií]a' THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$function$;


-- ===== database_sql/funciones/finanzas/fin_cuenta_documento_tiene_pagos.sql =====
CREATE OR REPLACE FUNCTION fin_cuenta_documento_tiene_pagos(
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_comprobante_compra INTEGER DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $function$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM fin_pago p
        JOIN fin_cuenta c ON c.id = p.id_cuenta
        WHERE p.estado = 1
          AND c.estado = 1
          AND (
              (
                  p_id_comprobante_venta IS NOT NULL
                  AND (
                      c.id_comprobante_venta = p_id_comprobante_venta
                      OR c.id_cuenta_padre IN (
                          SELECT fc.id
                          FROM fin_cuenta fc
                          WHERE fc.id_comprobante_venta = p_id_comprobante_venta
                            AND fc.estado = 1
                            AND fc.id_cuenta_padre IS NULL
                      )
                  )
              )
              OR (
                  p_id_comprobante_compra IS NOT NULL
                  AND (
                      c.id_comprobante_compra = p_id_comprobante_compra
                      OR c.id_cuenta_padre IN (
                          SELECT fc.id
                          FROM fin_cuenta fc
                          WHERE fc.id_comprobante_compra = p_id_comprobante_compra
                            AND fc.estado = 1
                            AND fc.id_cuenta_padre IS NULL
                      )
                  )
              )
          )
    );
END;
$function$;


-- ===== database_sql/funciones/finanzas/fin_bajar_cuentas_documento.sql =====
CREATE OR REPLACE FUNCTION fin_bajar_cuentas_documento(
    p_id_usuario INTEGER,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_comprobante_compra INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_padre INTEGER;
BEGIN
    FOR v_id_padre IN
        SELECT fc.id
        FROM fin_cuenta fc
        WHERE fc.estado = 1
          AND fc.id_cuenta_padre IS NULL
          AND (
              (p_id_comprobante_venta IS NOT NULL AND fc.id_comprobante_venta = p_id_comprobante_venta)
              OR (p_id_comprobante_compra IS NOT NULL AND fc.id_comprobante_compra = p_id_comprobante_compra)
          )
    LOOP
        UPDATE fin_cuenta
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_id_padre
           OR id_cuenta_padre = v_id_padre;
    END LOOP;
END;
$function$;


-- ===== database_sql/funciones/finanzas/fin_abonar_por_nota_credito.sql =====
-- Aplica la NC como abono a la CxC del comprobante origen (sin caja).
CREATE OR REPLACE FUNCTION fin_abonar_por_nota_credito(
    p_id_comprobante_origen INTEGER,
    p_id_nota_credito INTEGER,
    p_monto NUMERIC,
    p_id_usuario INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_restante NUMERIC(12,2);
    v_aplicar NUMERIC(12,2);
    v_hijo RECORD;
    v_serie VARCHAR;
    v_numero VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_restante := fin_redondear_monto(p_monto);
    IF v_restante IS NULL OR v_restante <= 0 OR p_id_comprobante_origen IS NULL THEN
        RETURN;
    END IF;

    SELECT serie, numero INTO v_serie, v_numero
    FROM ven_comprobante
    WHERE id = p_id_nota_credito;

    FOR v_hijo IN
        SELECT h.id, fin_redondear_monto(COALESCE(h.monto_saldo, 0)) AS saldo
        FROM fin_cuenta h
        WHERE h.estado = 1
          AND fin_redondear_monto(COALESCE(h.monto_saldo, 0)) > 0
          AND (
              (
                  h.id_comprobante_venta = p_id_comprobante_origen
                  AND h.id_cuenta_padre IS NULL
                  AND h.numero_cuotas_total IS NULL
              )
              OR h.id_cuenta_padre IN (
                  SELECT fc.id
                  FROM fin_cuenta fc
                  WHERE fc.id_comprobante_venta = p_id_comprobante_origen
                    AND fc.estado = 1
                    AND fc.id_cuenta_padre IS NULL
              )
          )
        ORDER BY COALESCE(h.numero_cuota, 0), h.fecha_vencimiento, h.id
    LOOP
        EXIT WHEN v_restante <= 0;
        IF v_hijo.saldo <= 0 THEN
            CONTINUE;
        END IF;

        v_aplicar := LEAST(v_restante, v_hijo.saldo);

        INSERT INTO fin_pago (
            id_cuenta, fecha_pago, monto, referencia, observacion, id_usuario_creacion
        ) VALUES (
            v_hijo.id,
            CURRENT_DATE,
            v_aplicar,
            format('NC %s-%s', COALESCE(v_serie, ''), COALESCE(v_numero, '')),
            format('Abono automático por nota de crédito #%s', p_id_nota_credito),
            p_id_usuario
        );

        UPDATE fin_cuenta
        SET monto_abonado = fin_redondear_monto(COALESCE(monto_abonado, 0) + v_aplicar),
            monto_saldo = fin_redondear_monto(GREATEST(monto_saldo - v_aplicar, 0)),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_hijo.id;

        IF (SELECT id_cuenta_padre FROM fin_cuenta WHERE id = v_hijo.id) IS NOT NULL THEN
            PERFORM fin_refrescar_cabecera_plan(
                (SELECT id_cuenta_padre FROM fin_cuenta WHERE id = v_hijo.id)
            );
        END IF;

        v_restante := fin_redondear_monto(v_restante - v_aplicar);
    END LOOP;
END;
$function$;


-- ===== database_sql/funciones/compras/com_generar_cxp_compra.sql =====
-- Genera CxP (fin_cuenta tipo PAGAR) para una compra según su condición de pago.
-- Idempotente: no crea nada si ya existe cuenta activa ligada a la compra.
-- Criterio (igual que ventas/CxC): dias_credito > 0 OR numero_cuotas > 1, y total > 0.
-- Fechas/montos se pueden personalizar con p_fecha_vencimiento (crédito) o p_cuotas (plan).

DROP FUNCTION IF EXISTS public.com_generar_cxp_compra(integer, integer);
DROP FUNCTION IF EXISTS public.com_generar_cxp_compra(integer, integer, date, jsonb);

CREATE OR REPLACE FUNCTION com_generar_cxp_compra(
    p_id_comprobante       INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_fecha_vencimiento    DATE DEFAULT NULL,
    p_cuotas               JSONB DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_proveedor      INTEGER;
    v_fecha             DATE;
    v_serie             VARCHAR;
    v_numero            VARCHAR;
    v_total             NUMERIC(12,4);
    v_id_condicion      INTEGER;
    v_estado            INTEGER;
    v_dias_credito      INTEGER := 0;
    v_numero_cuotas     INTEGER := 0;
    v_dia_mes_pago      INTEGER;
    v_fecha_primera     DATE;
    v_fecha_venc        DATE;
    v_mes_base          DATE;
    v_ultimo_dia_mes    DATE;
    v_id_tipo_pagar     INTEGER;
    v_cxp_result        JSON;
    v_numero_comp       VARCHAR;
    v_id_padre          INTEGER;
    v_cuota             JSONB;
    v_idx               INTEGER;
    v_fecha_cuota       DATE;
    v_monto_cuota       NUMERIC(12,4);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        c.id_proveedor,
        c.fecha,
        c.serie,
        c.numero,
        COALESCE(c.total_importe, 0),
        c.id_condicion_pago,
        c.estado
    INTO
        v_id_proveedor,
        v_fecha,
        v_serie,
        v_numero,
        v_total,
        v_id_condicion,
        v_estado
    FROM com_comprobante_compra c
    WHERE c.id = p_id_comprobante;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La compra id=% no existe', p_id_comprobante;
    END IF;

    IF v_estado <> 1 THEN
        RETURN;
    END IF;

    IF v_id_condicion IS NULL OR v_total <= 0 OR v_id_proveedor IS NULL THEN
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante
          AND fc.estado = 1
    ) THEN
        RETURN;
    END IF;

    SELECT
        COALESCE(cp.dias_credito, 0),
        COALESCE(cp.numero_cuotas, 0),
        cp.dia_mes_pago
    INTO v_dias_credito, v_numero_cuotas, v_dia_mes_pago
    FROM gen_condicion_pago cp
    WHERE cp.id = v_id_condicion
      AND cp.estado = 1;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF p_cuotas IS NOT NULL
       AND jsonb_typeof(p_cuotas) = 'array'
       AND jsonb_array_length(p_cuotas) > 1 THEN
        v_numero_cuotas := jsonb_array_length(p_cuotas);
        v_fecha_primera := COALESCE(
            NULLIF(p_cuotas->0->>'fechaPago', '')::DATE,
            NULLIF(p_cuotas->0->>'fecha_pago', '')::DATE
        );
        IF v_fecha_primera IS NOT NULL THEN
            v_dia_mes_pago := COALESCE(v_dia_mes_pago, EXTRACT(DAY FROM v_fecha_primera)::INTEGER);
        END IF;
    END IF;

    IF NOT (v_dias_credito > 0 OR v_numero_cuotas > 1) THEN
        RETURN;
    END IF;

    v_numero_comp := COALESCE(v_serie, '') || '-' || COALESCE(v_numero, '');

    IF v_numero_cuotas > 1 THEN
        IF v_fecha_primera IS NULL THEN
            IF v_dia_mes_pago IS NULL OR v_dia_mes_pago < 1 OR v_dia_mes_pago > 31 THEN
                RAISE EXCEPTION
                    'La condición de pago en cuotas requiere día del mes a pagar (1 a 31).';
            END IF;

            IF v_dias_credito > 0 THEN
                v_fecha_primera := v_fecha + v_dias_credito;
            ELSE
                v_mes_base := date_trunc('month', v_fecha)::date;
                v_ultimo_dia_mes := (v_mes_base + INTERVAL '1 month - 1 day')::date;
                v_fecha_primera := LEAST(
                    (v_mes_base + ((v_dia_mes_pago - 1) * INTERVAL '1 day'))::date,
                    v_ultimo_dia_mes
                );
                IF v_fecha_primera < v_fecha THEN
                    v_mes_base := (v_mes_base + INTERVAL '1 month')::date;
                    v_ultimo_dia_mes := (v_mes_base + INTERVAL '1 month - 1 day')::date;
                    v_fecha_primera := LEAST(
                        (v_mes_base + ((v_dia_mes_pago - 1) * INTERVAL '1 day'))::date,
                        v_ultimo_dia_mes
                    );
                END IF;
            END IF;
        END IF;

        IF v_dia_mes_pago IS NULL OR v_dia_mes_pago < 1 OR v_dia_mes_pago > 31 THEN
            v_dia_mes_pago := EXTRACT(DAY FROM v_fecha_primera)::INTEGER;
        END IF;

        v_cxp_result := fin_crear_cuenta_cuotas(
            'PAGAR',
            v_id_proveedor,
            NULL,
            v_fecha,
            v_total,
            v_numero_cuotas,
            v_fecha_primera,
            v_dia_mes_pago,
            format(
                'CxP en %s cuotas (día %s) %s',
                v_numero_cuotas,
                v_dia_mes_pago,
                v_numero_comp
            ),
            NULL,
            NULL,
            NULL,
            v_numero_comp,
            p_id_usuario_auditoria,
            NULL,
            p_id_comprobante
        );

        IF v_cxp_result->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_cxp_result->>'error';
        END IF;

        IF p_cuotas IS NOT NULL
           AND jsonb_typeof(p_cuotas) = 'array'
           AND jsonb_array_length(p_cuotas) > 0 THEN
            v_id_padre := (v_cxp_result->'registro'->>'id')::INTEGER;
            FOR v_idx IN 0 .. jsonb_array_length(p_cuotas) - 1 LOOP
                v_cuota := p_cuotas->v_idx;
                v_fecha_cuota := COALESCE(
                    NULLIF(v_cuota->>'fechaPago', '')::DATE,
                    NULLIF(v_cuota->>'fecha_pago', '')::DATE
                );
                v_monto_cuota := COALESCE(
                    NULLIF(v_cuota->>'monto', '')::NUMERIC,
                    NULL
                );
                UPDATE fin_cuenta h
                SET fecha_vencimiento = COALESCE(v_fecha_cuota, h.fecha_vencimiento),
                    monto_pendiente = COALESCE(v_monto_cuota, h.monto_pendiente),
                    monto_saldo = COALESCE(v_monto_cuota, h.monto_saldo)
                WHERE h.id_cuenta_padre = v_id_padre
                  AND h.numero_cuota = v_idx + 1
                  AND h.estado = 1;
            END LOOP;
        END IF;
    ELSE
        v_fecha_venc := COALESCE(p_fecha_vencimiento, v_fecha + v_dias_credito);

        SELECT glo.id
        INTO v_id_tipo_pagar
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoCuentaFinanciera'
          AND glo.nombre = 'PAGAR'
          AND glo.estado = 1
        LIMIT 1;

        IF v_id_tipo_pagar IS NULL THEN
            RAISE EXCEPTION
                'No está configurado el tipo de cuenta PAGAR (TipoCuentaFinanciera).';
        END IF;

        INSERT INTO fin_cuenta (
            id_tipo_cuenta,
            id_tercero,
            id_comprobante_compra,
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
            v_id_tipo_pagar,
            v_id_proveedor,
            p_id_comprobante,
            v_numero_comp,
            v_fecha,
            v_fecha_venc,
            v_total,
            0,
            v_total,
            format(
                'CxP por compra a crédito (%s días) %s',
                v_dias_credito,
                v_numero_comp
            ),
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END IF;
END;
$function$;


-- ===== database_sql/funciones/compras/com_sincronizar_cxp_compra.sql =====
-- Alinea la CxP con el total y la condición actuales de la compra.
-- Sin pagos: recrea o da de baja. Con pagos: solo permite si el total no cambió.
CREATE OR REPLACE FUNCTION com_sincronizar_cxp_compra(
    p_id_comprobante       INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_fecha_vencimiento    DATE DEFAULT NULL,
    p_cuotas               JSONB DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_total NUMERIC(12,4);
    v_id_condicion INTEGER;
    v_estado INTEGER;
    v_dias INTEGER := 0;
    v_cuotas INTEGER := 0;
    v_requiere BOOLEAN := FALSE;
    v_existe BOOLEAN := FALSE;
    v_hay_pagos BOOLEAN := FALSE;
    v_monto_actual NUMERIC(12,4);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(c.total_importe, 0), c.id_condicion_pago, c.estado
    INTO v_total, v_id_condicion, v_estado
    FROM com_comprobante_compra c
    WHERE c.id = p_id_comprobante;

    IF NOT FOUND OR v_estado <> 1 THEN
        RETURN;
    END IF;

    IF v_id_condicion IS NOT NULL THEN
        SELECT COALESCE(cp.dias_credito, 0), COALESCE(cp.numero_cuotas, 0)
        INTO v_dias, v_cuotas
        FROM gen_condicion_pago cp
        WHERE cp.id = v_id_condicion AND cp.estado = 1;
    END IF;

    IF p_cuotas IS NOT NULL
       AND jsonb_typeof(p_cuotas) = 'array'
       AND jsonb_array_length(p_cuotas) > 1 THEN
        v_cuotas := jsonb_array_length(p_cuotas);
    END IF;

    v_requiere := v_total > 0 AND (v_dias > 0 OR v_cuotas > 1);

    SELECT EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante
          AND fc.estado = 1
          AND fc.id_cuenta_padre IS NULL
    ) INTO v_existe;

    v_hay_pagos := fin_cuenta_documento_tiene_pagos(NULL, p_id_comprobante);

    IF NOT v_requiere THEN
        IF v_hay_pagos THEN
            RAISE EXCEPTION
                'No se puede pasar a contado: la cuenta por pagar ya tiene pagos. Anule los pagos en Finanzas.';
        END IF;
        IF v_existe THEN
            PERFORM fin_bajar_cuentas_documento(p_id_usuario_auditoria, NULL, p_id_comprobante);
        END IF;
        RETURN;
    END IF;

    IF v_hay_pagos THEN
        SELECT COALESCE(fc.monto_pendiente, 0)
        INTO v_monto_actual
        FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante
          AND fc.estado = 1
          AND fc.id_cuenta_padre IS NULL
        ORDER BY fc.id
        LIMIT 1;

        IF ABS(COALESCE(v_monto_actual, 0) - v_total) > 0.009 THEN
            RAISE EXCEPTION
                'No se puede cambiar el total de la compra: la CxP ya tiene pagos. Anule los pagos en Finanzas.';
        END IF;
        RETURN;
    END IF;

    IF v_existe THEN
        PERFORM fin_bajar_cuentas_documento(p_id_usuario_auditoria, NULL, p_id_comprobante);
    END IF;

    PERFORM com_generar_cxp_compra(
        p_id_comprobante,
        p_id_usuario_auditoria,
        p_fecha_vencimiento,
        p_cuotas
    );
END;
$function$;


-- ===== database_sql/funciones/compras/com_recalcular_totales_compra.sql =====
-- importe de cada línea se asume CON IGV incluido; se descompone en
-- base imponible (sub_total) + IGV (igv), igual que en com_crear_compra.
CREATE OR REPLACE FUNCTION com_recalcular_totales_compra(
    p_id_comprobante         INTEGER,
    p_id_usuario_auditoria   INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_total_bruto     NUMERIC(12,4);
    v_tasa_igv        NUMERIC(6,4) := 0.18;
    v_base_imponible  NUMERIC(12,4);
    v_igv_calculado   NUMERIC(12,4);
BEGIN
    SELECT COALESCE(SUM(importe), 0) INTO v_total_bruto
    FROM com_comprobante_compra_detalle
    WHERE id_comprobante = p_id_comprobante AND estado = 1;

    v_base_imponible := ROUND(v_total_bruto / (1 + v_tasa_igv), 4);
    v_igv_calculado := v_total_bruto - v_base_imponible;

    UPDATE com_comprobante_compra
    SET sub_total = v_base_imponible,
        igv = v_igv_calculado,
        total_importe = v_total_bruto,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    -- Si la cabecera se creó sin líneas (total 0) y ahora hay importe + crédito/cuotas,
    -- genera la CxP (idempotente si ya existe).
    PERFORM com_sincronizar_cxp_compra(p_id_comprobante, p_id_usuario_auditoria);
END;
$function$;


-- ===== database_sql/funciones/compras/com_actualizar_compra_cabecera.sql =====
-- Campos administrativos que NO afectan inventario.
-- Se permiten aunque la compra ya haya generado ingresos de stock.

DROP FUNCTION IF EXISTS public.com_actualizar_compra_cabecera(integer, character varying, integer, integer, boolean, integer);

CREATE OR REPLACE FUNCTION com_actualizar_compra_cabecera(
    p_id_comprobante         INTEGER,
    p_glosa                  VARCHAR DEFAULT NULL,
    p_id_condicion_pago      INTEGER DEFAULT NULL,
    p_id_categoria_gasto     INTEGER DEFAULT NULL,
    p_declarar_sunat         BOOLEAN DEFAULT NULL,
    p_id_usuario_auditoria   INTEGER DEFAULT NULL,
    p_fecha_vencimiento_cxp  DATE DEFAULT NULL,
    p_cuotas_cxp             JSONB DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante AND estado = 1) THEN
        RETURN json_build_object('error', 'La compra no existe o está anulada', 'registro', NULL);
    END IF;

    UPDATE com_comprobante_compra
    SET glosa               = COALESCE(p_glosa, glosa),
        id_condicion_pago   = COALESCE(p_id_condicion_pago, id_condicion_pago),
        id_categoria_gasto  = COALESCE(p_id_categoria_gasto, id_categoria_gasto),
        declarar_sunat      = COALESCE(p_declarar_sunat, declarar_sunat),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion  = NOW()
    WHERE id = p_id_comprobante;

    PERFORM com_sincronizar_cxp_compra(
        p_id_comprobante,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    RETURN com_obtener_compra(p_id_comprobante);
END;
$function$;


-- ===== database_sql/funciones/compras/com_revertir_cilindros_recarga_compra.sql =====
CREATE OR REPLACE FUNCTION com_revertir_cilindros_recarga_compra(
    p_id_recarga_planta INTEGER,
    p_id_comprobante INTEGER,
    p_id_usuario INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_det RECORD;
    v_estado VARCHAR;
    v_id_recarga_ext INTEGER;
    v_id_tipo_doc_compra INTEGER;
    v_id_tipo_doc_recarga INTEGER;
    v_id_tipo_entrada INTEGER;
BEGIN
    SELECT lo.id INTO v_id_recarga_ext
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_RECARGA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_entrada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovBalon'
      AND lo.nombre IN ('ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA')
      AND lo.estado = 1
    ORDER BY CASE lo.nombre WHEN 'ENTRADA_LLENADO' THEN 0 ELSE 1 END
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_compra
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'COMPRA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    FOR v_det IN
        SELECT d.id_balon
        FROM bal_recarga_planta_detalle d
        WHERE d.id_recarga_planta = p_id_recarga_planta
          AND d.estado = 1
    LOOP
        SELECT eb.nombre INTO v_estado
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.id = v_det.id_balon AND b.estado = 1;

        IF COALESCE(v_estado, '') NOT IN ('EN_ALMACEN', 'EN_RECARGA_EXTERNA') THEN
            RAISE EXCEPTION
                'No se puede anular la compra: el cilindro % ya no está en almacén ni en recarga externa (estado %).',
                v_det.id_balon,
                COALESCE(v_estado, 'sin estado');
        END IF;

        IF COALESCE(v_estado, '') = 'EN_ALMACEN' AND v_id_recarga_ext IS NOT NULL THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_recarga_ext,
                id_almacen = NULL,
                id_usuario_modificacion = p_id_usuario,
                fecha_modificacion = NOW()
            WHERE id = v_det.id_balon AND estado = 1;
        END IF;

        UPDATE bal_movimiento m
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE m.estado = 1
          AND m.id_balon = v_det.id_balon
          AND (
              (v_id_tipo_doc_compra IS NOT NULL AND m.id_documento_ref = p_id_comprobante AND m.id_tipo_documento_ref = v_id_tipo_doc_compra)
              OR (v_id_tipo_doc_recarga IS NOT NULL AND m.id_documento_ref = p_id_recarga_planta AND m.id_tipo_documento_ref = v_id_tipo_doc_recarga)
          )
          AND (
              v_id_tipo_entrada IS NULL
              OR m.id_tipo_movimiento IN (
                  SELECT lo.id
                  FROM gen_lista_opciones lo
                  INNER JOIN gen_lista l ON l.id = lo.id_lista
                  WHERE l.nombre = 'TipoMovBalon'
                    AND lo.nombre IN ('ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA')
              )
          );
    END LOOP;
END;
$function$;


-- ===== database_sql/funciones/compras/com_anular_compra.sql =====
CREATE OR REPLACE FUNCTION com_anular_compra(
    p_id_comprobante         INTEGER,
    p_id_usuario_auditoria   INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
    v_id_almacen_default  INTEGER;
    v_serie               VARCHAR;
    v_numero              VARCHAR;
    v_id_tipo_salida      INTEGER;
    v_id_tipo_doc_ref     INTEGER;
    v_result_movimiento   JSON;
    v_stock_actual        NUMERIC(12,4);
    v_faltantes           TEXT := '';
    v_nombre_producto     VARCHAR;
    v_nombre_almacen      VARCHAR;
    v_id_estado_retornado INTEGER;
    v_id_estado_enviado   INTEGER;
    v_orden               RECORD;
    v_hay_pagos_cxp       BOOLEAN;
    v_id_cuenta_padre     INTEGER;
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

    -- No anular si la CxP vinculada ya tiene pagos.
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

    SELECT glo.id INTO v_id_tipo_salida
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoMovInv' AND glo.nombre = 'SALIDA' AND glo.estado = 1;

    SELECT glo.id INTO v_id_tipo_doc_ref
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoDocumentoRef' AND glo.nombre = 'DEVOLUCION' AND glo.estado = 1;

    -- ---------- PASO 1: VALIDACIÓN COMPLETA (sin modificar nada aún) ----------
    -- Se bloquean (FOR UPDATE) las filas de pro_stock involucradas para que
    -- ninguna venta/compra concurrente cambie el stock entre esta validación
    -- y la reversa real del paso 2 (misma transacción, mismo lock).
    FOR v_detalle IN
        SELECT d.id, d.id_producto, d.cantidad,
               COALESCE(d.id_almacen, v_id_almacen_default) AS id_almacen
        FROM com_comprobante_compra_detalle d
        WHERE d.id_comprobante = p_id_comprobante
          AND d.afecta_stock = TRUE
          AND d.estado = 1
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
                E'\n- %s en %s: ingresó %s, disponible %s, falta %s',
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

    -- ---------- PASO 2: REVERSA REAL (ya validado que hay stock suficiente) ----------
    FOR v_detalle IN
        SELECT id, id_producto, cantidad, COALESCE(id_almacen, v_id_almacen_default) AS id_almacen
        FROM com_comprobante_compra_detalle
        WHERE id_comprobante = p_id_comprobante
          AND afecta_stock = TRUE
          AND estado = 1
    LOOP
        v_result_movimiento := pro_crear_movimiento(
            p_fecha                 => CURRENT_DATE,
            p_id_producto           => v_detalle.id_producto,
            p_id_almacen            => v_detalle.id_almacen,
            p_id_tipo_movimiento    => v_id_tipo_salida,
            p_cantidad              => v_detalle.cantidad,
            p_id_documento_ref      => v_detalle.id,
            p_id_tipo_documento_ref => v_id_tipo_doc_ref,
            p_glosa                 => 'Reversa por anulación de compra ' || v_serie || '-' || v_numero,
            p_id_usuario_auditoria  => p_id_usuario_auditoria,
            p_forzar_ajuste_stock   => TRUE
        );

        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo anular: %', v_result_movimiento->>'error';
        END IF;
    END LOOP;

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

    -- Desvincular órdenes de recarga planta que apuntaban a esta compra.
    SELECT lo.id INTO v_id_estado_retornado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecargaPlanta' AND lo.nombre = 'RETORNADO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_enviado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecargaPlanta' AND lo.nombre = 'ENVIADO' AND lo.estado = 1
    LIMIT 1;

    FOR v_orden IN
        SELECT id, fecha_llegada_almacen, id_almacen
        FROM bal_recarga_planta
        WHERE id_comprobante_compra = p_id_comprobante
          AND estado = 1
    LOOP
        PERFORM com_revertir_cilindros_recarga_compra(
            v_orden.id,
            p_id_comprobante,
            p_id_usuario_auditoria
        );

        UPDATE bal_recarga_planta
        SET
            id_comprobante_compra = NULL,
            serie_factura = NULL,
            numero_factura = NULL,
            id_estado = CASE
                WHEN v_orden.fecha_llegada_almacen IS NOT NULL THEN COALESCE(v_id_estado_retornado, id_estado)
                ELSE COALESCE(v_id_estado_enviado, id_estado)
            END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_orden.id;
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

    -- Baja lógica de CxP vinculada (cabeceras + cuotas hijas). Ya validado sin pagos.
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

    RETURN json_build_object('eliminado', TRUE, 'id', p_id_comprobante);
END;
$function$;


-- ===== database_sql/funciones/comprobantes/ven_sincronizar_cxc_venta.sql =====
CREATE OR REPLACE FUNCTION ven_sincronizar_cxc_venta(
    p_id_comprobante INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_total NUMERIC(12,4);
    v_id_condicion INTEGER;
    v_id_cliente INTEGER;
    v_fecha DATE;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_codigo_tipo VARCHAR;
    v_dias INTEGER := 0;
    v_cuotas INTEGER := 0;
    v_dia_mes INTEGER;
    v_requiere BOOLEAN := FALSE;
    v_existe BOOLEAN := FALSE;
    v_hay_pagos BOOLEAN := FALSE;
    v_monto_actual NUMERIC(12,4);
    v_fecha_venc DATE;
    v_id_tipo INTEGER;
    v_cxc JSON;
    v_mes_base DATE;
    v_ultimo DATE;
    v_fecha_primera DATE;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COALESCE(c.total_importe, 0),
        c.id_condicion_pago,
        c.id_cliente,
        c.fecha,
        c.serie,
        c.numero,
        tc.descripcion,
        c.fecha_vencimiento
    INTO
        v_total, v_id_condicion, v_id_cliente, v_fecha, v_serie, v_numero,
        v_codigo_tipo, v_fecha_venc
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones tc ON tc.id = c.id_tipo_comprobante
    WHERE c.id = p_id_comprobante AND c.estado = 1;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_codigo_tipo IN ('07', '08') THEN
        RETURN;
    END IF;

    IF v_id_condicion IS NOT NULL THEN
        SELECT COALESCE(cp.dias_credito, 0), COALESCE(cp.numero_cuotas, 0), cp.dia_mes_pago
        INTO v_dias, v_cuotas, v_dia_mes
        FROM gen_condicion_pago cp
        WHERE cp.id = v_id_condicion AND cp.estado = 1;
    END IF;

    v_requiere := v_total > 0 AND (v_dias > 0 OR v_cuotas > 1);

    SELECT EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_venta = p_id_comprobante
          AND fc.estado = 1
          AND fc.id_cuenta_padre IS NULL
    ) INTO v_existe;

    v_hay_pagos := fin_cuenta_documento_tiene_pagos(p_id_comprobante, NULL);

    IF NOT v_requiere THEN
        IF v_hay_pagos THEN
            RAISE EXCEPTION
                'No se puede pasar a contado: la cuenta por cobrar ya tiene pagos. Anule los pagos en Finanzas.';
        END IF;
        IF v_existe THEN
            PERFORM fin_bajar_cuentas_documento(p_id_usuario_auditoria, p_id_comprobante, NULL);
        END IF;
        RETURN;
    END IF;

    IF v_hay_pagos THEN
        SELECT COALESCE(fc.monto_pendiente, 0)
        INTO v_monto_actual
        FROM fin_cuenta fc
        WHERE fc.id_comprobante_venta = p_id_comprobante
          AND fc.estado = 1
          AND fc.id_cuenta_padre IS NULL
        ORDER BY fc.id
        LIMIT 1;

        IF ABS(COALESCE(v_monto_actual, 0) - v_total) > 0.009 THEN
            RAISE EXCEPTION
                'No se puede cambiar el total: la CxC ya tiene pagos. Anule los pagos en Finanzas.';
        END IF;
        RETURN;
    END IF;

    IF v_existe THEN
        PERFORM fin_bajar_cuentas_documento(p_id_usuario_auditoria, p_id_comprobante, NULL);
    END IF;

    IF v_cuotas > 1 THEN
        IF v_dia_mes IS NULL OR v_dia_mes < 1 OR v_dia_mes > 31 THEN
            RAISE EXCEPTION 'La condición de pago en cuotas requiere día del mes a cobrar (1 a 31).';
        END IF;
        IF v_fecha_venc IS NOT NULL THEN
            v_fecha_primera := v_fecha_venc;
        ELSIF v_dias > 0 THEN
            v_fecha_primera := COALESCE(v_fecha, CURRENT_DATE) + v_dias;
        ELSE
            v_mes_base := date_trunc('month', COALESCE(v_fecha, CURRENT_DATE))::date;
            v_ultimo := (v_mes_base + INTERVAL '1 month - 1 day')::date;
            v_fecha_primera := LEAST(
                (v_mes_base + ((v_dia_mes - 1) * INTERVAL '1 day'))::date,
                v_ultimo
            );
            IF v_fecha_primera < COALESCE(v_fecha, CURRENT_DATE) THEN
                v_mes_base := (v_mes_base + INTERVAL '1 month')::date;
                v_ultimo := (v_mes_base + INTERVAL '1 month - 1 day')::date;
                v_fecha_primera := LEAST(
                    (v_mes_base + ((v_dia_mes - 1) * INTERVAL '1 day'))::date,
                    v_ultimo
                );
            END IF;
        END IF;

        v_cxc := fin_crear_cuenta_cuotas(
            'COBRAR',
            v_id_cliente,
            NULL,
            COALESCE(v_fecha, CURRENT_DATE),
            v_total,
            v_cuotas,
            v_fecha_primera,
            v_dia_mes,
            format('CxC en %s cuotas (día %s) %s-%s', v_cuotas, v_dia_mes, v_serie, v_numero),
            NULL, NULL, NULL,
            v_serie || '-' || v_numero,
            p_id_usuario_auditoria,
            p_id_comprobante
        );
        IF v_cxc->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_cxc->>'error';
        END IF;
    ELSE
        v_fecha_venc := COALESCE(v_fecha_venc, COALESCE(v_fecha, CURRENT_DATE) + v_dias);

        SELECT glo.id INTO v_id_tipo
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = 'COBRAR' AND glo.estado = 1
        LIMIT 1;

        IF v_id_tipo IS NULL THEN
            RAISE EXCEPTION 'No está configurado el tipo de cuenta COBRAR.';
        END IF;

        INSERT INTO fin_cuenta (
            id_tipo_cuenta, id_tercero, id_comprobante_venta, numero_comprobante,
            fecha_emision, fecha_vencimiento, monto_pendiente, monto_abonado, monto_saldo,
            descripcion, id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            v_id_tipo, v_id_cliente, p_id_comprobante, v_serie || '-' || v_numero,
            COALESCE(v_fecha, CURRENT_DATE), v_fecha_venc, v_total, 0, v_total,
            format('CxC por venta a crédito (%s días) %s-%s', v_dias, v_serie, v_numero),
            p_id_usuario_auditoria, p_id_usuario_auditoria
        );
    END IF;
END;
$function$;


-- ===== database_sql/funciones/comprobantes/ven_revertir_efectos_comprobante.sql =====
-- Revierte kardex de producto y CxC impaga. No da de baja el CPE (eso lo hace eliminar/baja).
CREATE OR REPLACE FUNCTION ven_revertir_efectos_comprobante(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_exigir_sin_pagos BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_movimiento RECORD;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_afecta_stock BOOLEAN;
    v_es_salida BOOLEAN;
    v_nombre_tipo_movimiento VARCHAR;
    v_hay_pagos BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_hay_pagos := fin_cuenta_documento_tiene_pagos(p_id, NULL);

    IF p_exigir_sin_pagos AND v_hay_pagos THEN
        RETURN json_build_object(
            'ok', FALSE,
            'error', 'No se puede eliminar: la cuenta por cobrar tiene pagos. Anule primero los pagos en Finanzas.'
        );
    END IF;

    FOR v_movimiento IN
        SELECT *
        FROM pro_movimientos
        WHERE id_documento_ref = p_id
          AND estado = 1
        ORDER BY id
        FOR UPDATE
    LOOP
        SELECT COALESCE(afecta_stock, FALSE)
        INTO v_afecta_stock
        FROM pro_producto
        WHERE id = v_movimiento.id_producto;

        IF v_afecta_stock
           AND v_movimiento.stock_anterior IS NOT NULL
           AND v_movimiento.stock_nuevo IS NOT NULL THEN
            SELECT nombre INTO v_nombre_tipo_movimiento
            FROM gen_lista_opciones
            WHERE id = v_movimiento.id_tipo_movimiento;

            v_es_salida := v_nombre_tipo_movimiento ILIKE '%SALIDA%';

            SELECT id, stock INTO v_id_stock, v_stock_actual
            FROM pro_stock
            WHERE id_almacen = v_movimiento.id_almacen
              AND id_producto = v_movimiento.id_producto
              AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NULL THEN
                RETURN json_build_object(
                    'ok', FALSE,
                    'error', 'No se encontró el registro de stock para revertir el movimiento del comprobante'
                );
            END IF;

            IF v_es_salida THEN
                v_stock_revertido := v_stock_actual + v_movimiento.cantidad;
            ELSE
                v_stock_revertido := v_stock_actual - v_movimiento.cantidad;
            END IF;

            IF v_stock_revertido < 0 THEN
                RETURN json_build_object(
                    'ok', FALSE,
                    'error', 'No se puede revertir el comprobante porque dejaría stock negativo'
                );
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_revertido,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_stock;
        END IF;

        UPDATE pro_movimientos
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_movimiento.id AND estado = 1;
    END LOOP;

    IF NOT v_hay_pagos THEN
        PERFORM fin_bajar_cuentas_documento(p_id_usuario_auditoria, p_id, NULL);
    END IF;

    RETURN json_build_object('ok', TRUE, 'error', NULL);
END;
$function$;


-- ===== database_sql/funciones/comprobantes/ven_crear_comprobante.sql =====
-- precio_unitario en detalles se asume CON IGV incluido (descompone base + impuesto).
CREATE OR REPLACE FUNCTION ven_crear_comprobante(
    p_id_tipo_comprobante INTEGER,
    p_serie VARCHAR,
    p_numero VARCHAR DEFAULT NULL,
    p_fecha DATE DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_detalles JSON DEFAULT '[]'::JSON,
    p_id_tipo_operacion_sunat INTEGER DEFAULT NULL,
    p_id_comprobante_origen INTEGER DEFAULT NULL,
    p_id_motivo_nota INTEGER DEFAULT NULL,
    p_id_tipo_movimiento INTEGER DEFAULT NULL,
    p_id_tipo_venta INTEGER DEFAULT NULL,
    p_fecha_vencimiento DATE DEFAULT NULL,
    p_tipo_cambio NUMERIC DEFAULT 3.5,
    p_id_sucursal INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_condicion_pago INTEGER DEFAULT NULL,
    p_id_moneda INTEGER DEFAULT NULL,
    p_id_medio_pago INTEGER DEFAULT NULL,
    p_glosa VARCHAR DEFAULT NULL,
    p_observaciones VARCHAR DEFAULT NULL,
    p_periodo_contable VARCHAR DEFAULT NULL,
    p_operacion VARCHAR DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_cuotas JSON DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_origen_pos VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
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
    v_id_tipo_documento_ref INTEGER;
    v_nombre_tipo_venta VARCHAR;
    v_stock_disponible NUMERIC(12,4);
    v_mov_result JSON;
    v_glosa_mov VARCHAR;
    v_qty_origen NUMERIC(12,4);
    v_qty_nueva NUMERIC(12,4);
    v_delta_stock NUMERIC(12,4);
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

    -- Operación del día: requiere caja ABIERTA (arqueo / control operativo)
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

    v_es_nota_credito := (v_codigo_tipo = '07');

    -- Conversión VSD/NV → boleta/factura: el stock ya se descontó en el origen
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

    IF NULLIF(TRIM(p_numero), '') IS NULL THEN
        SELECT (ven_obtener_siguiente_numero(p_id_tipo_comprobante, v_serie)->>'numero')
        INTO v_numero;
    ELSE
        v_numero := LPAD(TRIM(p_numero), 8, '0');
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

        SELECT
            REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
            COALESCE(p.es_gas, FALSE),
            COALESCE(p.es_servicio, FALSE),
            COALESCE(p.afecta_stock, FALSE)
        INTO v_nombre_unidad, v_es_gas, v_es_servicio, v_afecta_stock
        FROM pro_producto p
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        WHERE p.id = v_id_producto;

        -- Gases (m³) pueden ser decimales aunque la U.M. esté mal catalogada como UNID.
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

        -- Servicios, alquiler (tarifa) y garantía no descuentan stock.
        IF NOT ven_producto_mueve_kardex_venta(v_id_producto, v_detalle->>'descripcion') THEN
            v_afecta_stock := FALSE;
        END IF;

        -- ND (08) no mueve stock. Conversión VSD→CPE reutiliza el descuento previo.
        IF v_afecta_stock AND NOT v_es_conversion_vsd AND v_codigo_tipo <> '08' THEN
            v_requiere_stock := TRUE;
        END IF;

        -- precio_unitario del catálogo ya incluye IGV
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

        SELECT lo.id INTO v_id_tipo_documento_ref
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoDocumentoRef'
          AND lo.nombre = CASE
            WHEN v_nombre_tipo_venta = 'VENTA_GAS' THEN 'RECARGA'
            WHEN v_codigo_tipo = '01' THEN 'FACTURA'
            WHEN v_codigo_tipo = '03' THEN 'BOLETA'
            WHEN v_codigo_tipo = '07' THEN 'NOTA_CREDITO'
            WHEN v_codigo_tipo = '08' THEN 'NOTA_DEBITO'
            WHEN v_codigo_tipo IN ('NV', 'VSD') THEN 'NOTA_VENTA'
            ELSE 'FACTURA'
          END
          AND lo.estado = 1
        LIMIT 1;

        -- Validar disponibilidad solo cuando se descuenta (no en NC)
        IF NOT v_es_nota_credito THEN
            FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
            LOOP
                v_id_producto := (v_detalle->>'id_producto')::INTEGER;
                v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);

                IF NOT ven_producto_mueve_kardex_venta(
                    v_id_producto,
                    v_detalle->>'descripcion'
                ) THEN
                    CONTINUE;
                END IF;

                SELECT COALESCE(s.stock, 0)
                INTO v_stock_disponible
                FROM pro_stock s
                WHERE s.id_almacen = p_id_almacen
                  AND s.id_producto = v_id_producto
                  AND s.estado = 1;

                IF v_stock_disponible IS NULL THEN
                    v_stock_disponible := 0;
                END IF;

                IF v_stock_disponible < v_cantidad THEN
                    RETURN json_build_object(
                        'error',
                        format(
                            'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                            COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                            v_stock_disponible,
                            v_cantidad
                        ),
                        'registro',
                        NULL
                    );
                END IF;
            END LOOP;
        END IF;
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
    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_item := v_item + 1;
        v_id_producto := (v_detalle->>'id_producto')::INTEGER;
        v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
        v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
        v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
        v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);
        -- precio_unitario del catálogo ya incluye IGV
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

    IF v_es_conversion_vsd THEN
        -- Reasignar movimientos del VSD al CPE y ajustar solo diferencias de cantidad
        SELECT lo.nombre INTO v_nombre_tipo_venta
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_venta;

        SELECT lo.id INTO v_id_tipo_documento_ref
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoDocumentoRef'
          AND lo.nombre = CASE
            WHEN v_nombre_tipo_venta = 'VENTA_GAS' THEN 'RECARGA'
            WHEN v_codigo_tipo = '01' THEN 'FACTURA'
            WHEN v_codigo_tipo = '03' THEN 'BOLETA'
            ELSE 'FACTURA'
          END
          AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_mov_inv
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'SALIDA' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_mov_ingreso
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'INGRESO' AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_mov_inv IS NULL OR v_id_tipo_mov_ingreso IS NULL THEN
            RAISE EXCEPTION 'No se encontraron tipos de movimiento SALIDA/INGRESO para la conversión';
        END IF;

        UPDATE pro_movimientos
        SET id_documento_ref = v_id,
            id_tipo_documento_ref = COALESCE(v_id_tipo_documento_ref, id_tipo_documento_ref),
            glosa = COALESCE(
                NULLIF(TRIM(p_glosa), ''),
                format('Salida por comprobante %s-%s (desde venta sin documento)', v_serie, v_numero)
            ),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_documento_ref = p_id_comprobante_origen
          AND estado = 1;

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

                v_mov_result := pro_crear_movimiento(
                    p_fecha,
                    v_id_producto,
                    p_id_almacen,
                    v_id_tipo_mov_inv,
                    v_delta_stock,
                    v_id,
                    v_id_tipo_documento_ref,
                    format('Ajuste conversión %s-%s (+)', v_serie, v_numero),
                    p_id_usuario_auditoria
                );
            ELSE
                v_mov_result := pro_crear_movimiento(
                    p_fecha,
                    v_id_producto,
                    p_id_almacen,
                    v_id_tipo_mov_ingreso,
                    ABS(v_delta_stock),
                    v_id,
                    v_id_tipo_documento_ref,
                    format('Ajuste conversión %s-%s (-)', v_serie, v_numero),
                    p_id_usuario_auditoria
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

        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_id_producto := (v_detalle->>'id_producto')::INTEGER;
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);

            SELECT ven_producto_mueve_kardex_venta(
                v_id_producto,
                v_detalle->>'descripcion'
            )
            INTO v_afecta_stock;

            IF NOT v_afecta_stock THEN
                CONTINUE;
            END IF;

            v_mov_result := pro_crear_movimiento(
                p_fecha,
                v_id_producto,
                p_id_almacen,
                v_id_tipo_mov_inv,
                v_cantidad,
                v_id,
                v_id_tipo_documento_ref,
                v_glosa_mov,
                p_id_usuario_auditoria
            );

            IF v_mov_result->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov_result->>'error';
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

    -- Crédito / cuotas: genera CxC vinculada al comprobante según condición de pago.
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

                    -- Primera cuota: fecha vencimiento explícita, o emisión + días, o próximo día_mes_pago
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
                    -- Crédito simple (un solo vencimiento)
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
    END IF;

    RETURN ven_obtener_comprobante(v_id);
END;
$function$;


-- ===== database_sql/funciones/comprobantes/ven_actualizar_comprobante.sql =====
-- precio_unitario en detalles se asume CON IGV incluido (descompone base + impuesto).
CREATE OR REPLACE FUNCTION ven_actualizar_comprobante(
    p_id INTEGER,
    p_fecha DATE DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_detalles JSON DEFAULT NULL,
    p_id_tipo_operacion_sunat INTEGER DEFAULT NULL,
    p_id_comprobante_origen INTEGER DEFAULT NULL,
    p_id_motivo_nota INTEGER DEFAULT NULL,
    p_id_tipo_movimiento INTEGER DEFAULT NULL,
    p_id_tipo_venta INTEGER DEFAULT NULL,
    p_fecha_vencimiento DATE DEFAULT NULL,
    p_tipo_cambio NUMERIC DEFAULT NULL,
    p_id_sucursal INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_condicion_pago INTEGER DEFAULT NULL,
    p_id_moneda INTEGER DEFAULT NULL,
    p_id_medio_pago INTEGER DEFAULT NULL,
    p_glosa VARCHAR DEFAULT NULL,
    p_observaciones VARCHAR DEFAULT NULL,
    p_periodo_contable VARCHAR DEFAULT NULL,
    p_operacion VARCHAR DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_cuotas JSON DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_origen_pos VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
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
    v_id_tipo_documento_ref INTEGER;
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
BEGIN
    SET TIME ZONE 'America/Lima';

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

    -- VSD/NV ya convertida: no permitir editar (stock ya vinculado al CPE destino)
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

            -- precio_unitario del catálogo ya incluye IGV
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

    -- Ajuste de stock por diferencias de detalle / cambio de almacén
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

            SELECT lo.id INTO v_id_tipo_documento_ref
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoDocumentoRef'
              AND lo.nombre = CASE
                WHEN v_nombre_tipo_venta = 'VENTA_GAS' THEN 'RECARGA'
                WHEN v_codigo_tipo = '01' THEN 'FACTURA'
                WHEN v_codigo_tipo = '03' THEN 'BOLETA'
                WHEN v_codigo_tipo = '07' THEN 'NOTA_CREDITO'
                WHEN v_codigo_tipo IN ('NV', 'VSD') THEN 'NOTA_VENTA'
                ELSE 'FACTURA'
              END
              AND lo.estado = 1
            LIMIT 1;

            IF p_detalles IS NULL THEN
                -- Solo cambia almacén: revertir en el anterior y aplicar en el nuevo
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
                            -- NC había ingresado: al salir del almacén viejo se revierte con SALIDA
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                        END IF;

                        v_mov_result := pro_crear_movimiento(
                            v_fecha,
                            v_id_producto,
                            v_id_almacen_actual,
                            v_id_tipo_mov_aplicar,
                            v_qty_antigua,
                            p_id,
                            v_id_tipo_documento_ref,
                            format('Cambio almacén %s-%s (revertir)', v_serie, v_numero),
                            p_id_usuario_auditoria
                        );
                        IF v_mov_result->>'error' IS NOT NULL THEN
                            RETURN json_build_object('error', v_mov_result->>'error', 'registro', NULL);
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
                                RETURN json_build_object(
                                    'error',
                                    format(
                                        'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                        COALESCE(v_stock_disponible, 0),
                                        v_qty_antigua
                                    ),
                                    'registro',
                                    NULL
                                );
                            END IF;
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                        END IF;

                        v_mov_result := pro_crear_movimiento(
                            v_fecha,
                            v_id_producto,
                            v_id_almacen_nuevo,
                            v_id_tipo_mov_aplicar,
                            v_qty_antigua,
                            p_id,
                            v_id_tipo_documento_ref,
                            format('Cambio almacén %s-%s (aplicar)', v_serie, v_numero),
                            p_id_usuario_auditoria
                        );
                        IF v_mov_result->>'error' IS NOT NULL THEN
                            RETURN json_build_object('error', v_mov_result->>'error', 'registro', NULL);
                        END IF;
                    END LOOP;
                END IF;
            ELSIF v_id_almacen_actual IS DISTINCT FROM v_id_almacen_nuevo THEN
                -- Cambia almacén y detalle: revertir todo lo antiguo y aplicar lo nuevo
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

                    v_mov_result := pro_crear_movimiento(
                        v_fecha,
                        v_id_producto,
                        v_id_almacen_actual,
                        v_id_tipo_mov_aplicar,
                        v_qty_antigua,
                        p_id,
                        v_id_tipo_documento_ref,
                        format('Cambio almacén %s-%s (revertir)', v_serie, v_numero),
                        p_id_usuario_auditoria
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RETURN json_build_object('error', v_mov_result->>'error', 'registro', NULL);
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
                            RETURN json_build_object(
                                'error',
                                format(
                                    'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                    COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                    COALESCE(v_stock_disponible, 0),
                                    v_qty_nueva
                                ),
                                'registro',
                                NULL
                            );
                        END IF;
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                    END IF;

                    v_mov_result := pro_crear_movimiento(
                        v_fecha,
                        v_id_producto,
                        v_id_almacen_nuevo,
                        v_id_tipo_mov_aplicar,
                        v_qty_nueva,
                        p_id,
                        v_id_tipo_documento_ref,
                        format('Ajuste edición %s-%s', v_serie, v_numero),
                        p_id_usuario_auditoria
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RETURN json_build_object('error', v_mov_result->>'error', 'registro', NULL);
                    END IF;
                END LOOP;
            ELSE
                -- Mismo almacén: solo deltas por producto
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

                    -- Venta: +qty → SALIDA; -qty → INGRESO. NC: sentido inverso.
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
                                RETURN json_build_object(
                                    'error',
                                    format(
                                        'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                        COALESCE(v_stock_disponible, 0),
                                        v_delta_stock
                                    ),
                                    'registro',
                                    NULL
                                );
                            END IF;
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                            v_cantidad_aplicar := v_delta_stock;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                            v_cantidad_aplicar := ABS(v_delta_stock);
                        END IF;
                    END IF;

                    v_mov_result := pro_crear_movimiento(
                        v_fecha,
                        v_id_producto,
                        v_id_almacen_nuevo,
                        v_id_tipo_mov_aplicar,
                        v_cantidad_aplicar,
                        p_id,
                        v_id_tipo_documento_ref,
                        format('Ajuste edición %s-%s', v_serie, v_numero),
                        p_id_usuario_auditoria
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RETURN json_build_object('error', v_mov_result->>'error', 'registro', NULL);
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
        UPDATE ven_comprobante_detalle
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_comprobante = p_id AND estado = 1;

        v_item := 0;
        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_item := v_item + 1;
            v_id_producto := (v_detalle->>'id_producto')::INTEGER;
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
            v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
            v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
            v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);
            -- precio_unitario del catálogo ya incluye IGV
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

    IF NOT v_es_nota_credito THEN
        PERFORM ven_sincronizar_cxc_venta(p_id, p_id_usuario_auditoria);
    END IF;

    RETURN ven_obtener_comprobante(p_id);
END;
$function$;


-- ===== database_sql/funciones/comprobantes/ven_eliminar_comprobante.sql =====
CREATE OR REPLACE FUNCTION ven_eliminar_comprobante(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_rev JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT es.nombre INTO v_estado_sunat
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
    WHERE c.id = p_id AND c.estado = 1;

    IF v_estado_sunat IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_estado_sunat = 'ACEPTADO' THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar un comprobante ya aceptado por SUNAT. Use nota de crédito o comunicación de baja.'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ven_comprobante
        WHERE id_comprobante_origen = p_id
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque tiene documentos derivados (boleta/factura/nota)'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_prestamo
        WHERE estado = 1 AND id_comprobante_venta = p_id
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque está vinculado a un préstamo'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_alquiler
        WHERE estado = 1 AND id_comprobante_venta = p_id
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque está vinculado a un alquiler'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_mantenimiento
        WHERE estado = 1 AND id_comprobante_venta = p_id
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque está vinculado a un mantenimiento'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_movimiento_recarga
        WHERE estado = 1 AND id_comprobante = p_id
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque está vinculado a una recarga'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM ven_garantia_movimiento
        WHERE estado = 1 AND id_comprobante = p_id
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque está vinculado a un movimiento de garantía'
        );
    END IF;

    -- Revertir stock y CxC impaga
    v_rev := ven_revertir_efectos_comprobante(p_id, p_id_usuario_auditoria, TRUE);
    IF COALESCE(v_rev->>'ok', 'false') <> 'true' THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', COALESCE(v_rev->>'error', 'No se pudieron revertir los efectos del comprobante')
        );
    END IF;

    UPDATE ven_comprobante_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_cuotas
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_comprobante
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ===== database_sql/funciones/movimientos-balon/bal_aplicar_custodia_tipo_movimiento.sql =====
-- Aplica el Libro (custodia viva) según TipoMovBalon. Solo movimientos sin documento.
CREATE OR REPLACE FUNCTION bal_aplicar_custodia_tipo_movimiento(
    p_id_movimiento INTEGER,
    p_revertir BOOLEAN DEFAULT FALSE,
    p_id_usuario INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_mov RECORD;
    v_tipo TEXT;
    v_codigo_estado TEXT;
    v_id_estado INTEGER;
    v_almacen INTEGER;
    v_cliente INTEGER;
    v_limpiar_almacen BOOLEAN := FALSE;
    v_contenido TEXT;
BEGIN
    SELECT
        m.id_balon,
        m.id_documento_ref,
        m.id_cliente,
        m.id_almacen_origen,
        m.id_almacen_destino,
        lo.nombre AS tipo
    INTO v_mov
    FROM bal_movimiento m
    LEFT JOIN gen_lista_opciones lo ON lo.id = m.id_tipo_movimiento
    WHERE m.id = p_id_movimiento;

    IF NOT FOUND OR v_mov.id_documento_ref IS NOT NULL THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    v_tipo := v_mov.tipo;

    IF p_revertir THEN
        v_codigo_estado := 'EN_ALMACEN';
        v_almacen := COALESCE(v_mov.id_almacen_origen, v_mov.id_almacen_destino);
        v_cliente := NULL;
        v_limpiar_almacen := FALSE;
    ELSE
        CASE v_tipo
            WHEN 'SALIDA_PRESTAMO' THEN
                v_codigo_estado := 'PRESTADO_CLIENTE';
                v_cliente := v_mov.id_cliente;
                v_limpiar_almacen := TRUE;
            WHEN 'SALIDA_ALQUILER' THEN
                v_codigo_estado := 'ALQUILADO';
                v_cliente := v_mov.id_cliente;
                v_limpiar_almacen := TRUE;
            WHEN 'SALIDA_VENTA' THEN
                v_codigo_estado := 'EN_PODER_CLIENTE';
                v_cliente := v_mov.id_cliente;
                v_limpiar_almacen := TRUE;
            WHEN 'SALIDA_ENTREGA_CLIENTE' THEN
                v_codigo_estado := 'EN_PODER_CLIENTE';
                v_cliente := v_mov.id_cliente;
                v_limpiar_almacen := TRUE;
            WHEN 'SALIDA_MANTENIMIENTO' THEN
                v_codigo_estado := 'EN_MANTENIMIENTO';
                v_almacen := COALESCE(v_mov.id_almacen_destino, v_mov.id_almacen_origen);
            WHEN 'SALIDA_PLANTA_EXTERNA' THEN
                v_codigo_estado := 'EN_RECARGA_EXTERNA';
                v_limpiar_almacen := TRUE;
                v_contenido := 'VACIO';
            WHEN 'ENTRADA_DEVOLUCION', 'ENTRADA_MANTENIMIENTO', 'RETORNO_LIMA' THEN
                v_codigo_estado := 'EN_ALMACEN';
                v_almacen := COALESCE(v_mov.id_almacen_destino, v_mov.id_almacen_origen);
            WHEN 'ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA' THEN
                v_codigo_estado := 'EN_ALMACEN';
                v_almacen := COALESCE(v_mov.id_almacen_destino, v_mov.id_almacen_origen);
                v_contenido := 'LLENO';
            WHEN 'RECARGA_CLIENTE' THEN
                v_codigo_estado := 'EN_PODER_CLIENTE';
                v_cliente := v_mov.id_cliente;
                v_limpiar_almacen := TRUE;
            WHEN 'TRASLADO_LIMA' THEN
                v_codigo_estado := 'EN_RUTA_LIMA';
                v_limpiar_almacen := TRUE;
            ELSE
                RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
        END CASE;
    END IF;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = v_codigo_estado AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object('ok', FALSE, 'error', format('Estado %s no configurado', v_codigo_estado));
    END IF;

    UPDATE bal_balon
    SET
        id_estado_balon = v_id_estado,
        id_cliente_ubicacion = CASE
            WHEN v_limpiar_almacen THEN v_cliente
            WHEN v_cliente IS NOT NULL THEN v_cliente
            ELSE NULL
        END,
        id_almacen = CASE
            WHEN v_limpiar_almacen THEN NULL
            ELSE v_almacen
        END,
        id_estado_contenido = CASE
            WHEN v_contenido IS NOT NULL THEN COALESCE(bal_id_estado_contenido(v_contenido), id_estado_contenido)
            ELSE id_estado_contenido
        END,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = v_mov.id_balon AND estado = 1;

    RETURN json_build_object('ok', TRUE, 'skipped', FALSE);
END;
$function$;


-- ===== database_sql/funciones/movimientos-balon/bal_crear_movimiento.sql =====
CREATE OR REPLACE FUNCTION bal_crear_movimiento(
    p_id_balon INTEGER,
    p_id_tipo_movimiento INTEGER DEFAULT NULL,
    p_id_documento_ref INTEGER DEFAULT NULL,
    p_id_tipo_documento_ref INTEGER DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_almacen_origen INTEGER DEFAULT NULL,
    p_id_almacen_destino INTEGER DEFAULT NULL,
    p_fecha_movimiento TIMESTAMP DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_tipo_movimiento IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_movimiento AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de movimiento indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    INSERT INTO bal_movimiento (
        id_balon, id_tipo_movimiento, id_documento_ref, id_tipo_documento_ref,
        id_cliente, id_almacen_origen, id_almacen_destino,
        fecha_movimiento, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_balon, p_id_tipo_movimiento, p_id_documento_ref, p_id_tipo_documento_ref,
        p_id_cliente, p_id_almacen_origen, p_id_almacen_destino,
        COALESCE(p_fecha_movimiento, NOW()), p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    PERFORM bal_aplicar_custodia_tipo_movimiento(v_id, FALSE, p_id_usuario_auditoria);

    RETURN bal_obtener_movimiento(v_id);
END;
$function$;


-- ===== database_sql/funciones/movimientos-balon/bal_actualizar_movimiento.sql =====
CREATE OR REPLACE FUNCTION bal_actualizar_movimiento(
    p_id INTEGER,
    p_id_tipo_movimiento INTEGER DEFAULT NULL,
    p_id_documento_ref INTEGER DEFAULT NULL,
    p_id_tipo_documento_ref INTEGER DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_almacen_origen INTEGER DEFAULT NULL,
    p_id_almacen_destino INTEGER DEFAULT NULL,
    p_fecha_movimiento TIMESTAMP DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE bal_movimiento
    SET
        id_tipo_movimiento = COALESCE(p_id_tipo_movimiento, id_tipo_movimiento),
        id_documento_ref = COALESCE(p_id_documento_ref, id_documento_ref),
        id_tipo_documento_ref = COALESCE(p_id_tipo_documento_ref, id_tipo_documento_ref),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_almacen_origen = COALESCE(p_id_almacen_origen, id_almacen_origen),
        id_almacen_destino = COALESCE(p_id_almacen_destino, id_almacen_destino),
        fecha_movimiento = COALESCE(p_fecha_movimiento, fecha_movimiento),
        observacion = COALESCE(p_observacion, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    PERFORM bal_aplicar_custodia_tipo_movimiento(p_id, FALSE, p_id_usuario_auditoria);

    RETURN bal_obtener_movimiento(p_id);
END;
$function$;


-- ===== database_sql/funciones/movimientos-balon/bal_eliminar_movimiento.sql =====
CREATE OR REPLACE FUNCTION bal_eliminar_movimiento(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_documento_ref INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_documento_ref
    INTO v_id_documento_ref
    FROM bal_movimiento
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_id_documento_ref IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el movimiento porque está vinculado a un documento de origen'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_baja_balon WHERE id_movimiento = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el movimiento porque está vinculado a una baja de cilindro'
        );
    END IF;

    PERFORM bal_aplicar_custodia_tipo_movimiento(p_id, TRUE, p_id_usuario_auditoria);

    UPDATE bal_movimiento
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ===== database_sql/funciones/movimientos-balon/bal_revertir_salidas_guia_remision.sql =====
-- Devuelve a almacén los cilindros de una GRE que ya no van (o todos si p_conservar es NULL).
CREATE OR REPLACE FUNCTION bal_revertir_salidas_guia_remision(
    p_id_guia INTEGER,
    p_ids_conservar INTEGER[] DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_doc INTEGER;
    v_mov RECORD;
    v_estado VARCHAR;
    v_id_en_almacen INTEGER;
    v_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_id_tipo_doc
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'GRE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_doc IS NULL THEN
        RETURN json_build_object('ok', TRUE, 'error', NULL);
    END IF;

    SELECT lo.id INTO v_id_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
    LIMIT 1;

    FOR v_mov IN
        SELECT m.id, m.id_balon, m.id_almacen_origen, tm.nombre AS tipo_mov
        FROM bal_movimiento m
        LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
        WHERE m.estado = 1
          AND m.id_documento_ref = p_id_guia
          AND m.id_tipo_documento_ref = v_id_tipo_doc
          AND (
              p_ids_conservar IS NULL
              OR NOT (m.id_balon = ANY (p_ids_conservar))
          )
        ORDER BY m.id
    LOOP
        SELECT eb.nombre INTO v_estado
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.id = v_mov.id_balon AND b.estado = 1;

        v_almacen := v_mov.id_almacen_origen;

        IF v_id_en_almacen IS NOT NULL
           AND COALESCE(v_estado, '') IN (
               'PRESTADO_CLIENTE', 'EN_RECARGA_EXTERNA', 'EN_RUTA_LIMA', 'EN_PODER_CLIENTE'
           )
        THEN
            IF v_almacen IS NULL THEN
                RETURN json_build_object(
                    'ok', FALSE,
                    'error', format(
                        'No se puede devolver el cilindro %s: la guía no tiene almacén de origen',
                        v_mov.id_balon
                    )
                );
            END IF;

            UPDATE bal_balon
            SET
                id_estado_balon = v_id_en_almacen,
                id_cliente_ubicacion = NULL,
                id_almacen = v_almacen,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_mov.id_balon AND estado = 1;
        END IF;

        UPDATE bal_movimiento
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_mov.id AND estado = 1;
    END LOOP;

    RETURN json_build_object('ok', TRUE, 'error', NULL);
END;
$function$;


-- ===== database_sql/funciones/guias-remision/gre_actualizar_guia_remision.sql =====
DROP FUNCTION IF EXISTS gre_actualizar_guia_remision(
    INTEGER, DATE, DATE, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, NUMERIC,
    INTEGER, VARCHAR, INTEGER, INTEGER, VARCHAR, VARCHAR, VARCHAR, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, VARCHAR, JSON, JSON, INTEGER
);

CREATE OR REPLACE FUNCTION gre_actualizar_guia_remision(
    p_id INTEGER,
    p_fecha DATE DEFAULT NULL,
    p_fecha_traslado DATE DEFAULT NULL,
    p_id_sucursal INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_motivo_traslado INTEGER DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_peso_bruto NUMERIC DEFAULT NULL,
    p_numero_bultos INTEGER DEFAULT NULL,
    p_direccion_origen VARCHAR DEFAULT NULL,
    p_id_distrito_origen INTEGER DEFAULT NULL,
    p_id_destinatario INTEGER DEFAULT NULL,
    p_destinatario_nombre VARCHAR DEFAULT NULL,
    p_destinatario_documento VARCHAR DEFAULT NULL,
    p_direccion_llegada VARCHAR DEFAULT NULL,
    p_id_distrito_llegada INTEGER DEFAULT NULL,
    p_id_modalidad_traslado INTEGER DEFAULT NULL,
    p_id_transportista INTEGER DEFAULT NULL,
    p_id_chofer INTEGER DEFAULT NULL,
    p_id_vehiculo INTEGER DEFAULT NULL,
    p_id_responsable INTEGER DEFAULT NULL,
    p_observaciones VARCHAR DEFAULT NULL,
    p_detalles JSON DEFAULT NULL,
    p_referencias JSON DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_remitente_nombre VARCHAR DEFAULT NULL,
    p_remitente_documento VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_codigo_modalidad VARCHAR;
    v_codigo_tipo VARCHAR;
    v_id_tipo INTEGER;
    v_id_modalidad INTEGER;
    v_id_destinatario INTEGER;
    v_destinatario_nombre VARCHAR(255);
    v_destinatario_documento VARCHAR(20);
    v_id_cliente INTEGER;
    v_remitente_nombre VARCHAR(255);
    v_remitente_documento VARCHAR(20);
    v_id_distrito_origen INTEGER;
    v_id_distrito_llegada INTEGER;
    v_peso NUMERIC;
    v_detalle JSON;
    v_ref JSON;
    v_item INTEGER := 0;
    v_salidas JSON;
    v_ids_conservar INTEGER[] := ARRAY[]::INTEGER[];
    v_id_balon_linea INTEGER;
    v_rev JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT es.nombre, g.id_tipo_guia_remision
    INTO v_estado_sunat, v_id_tipo
    FROM gre_guia_remision g
    LEFT JOIN gen_lista_opciones es ON g.id_estado_sunat = es.id
    WHERE g.id = p_id AND g.estado = 1;

    IF v_estado_sunat IS NULL AND v_id_tipo IS NULL THEN
        RETURN json_build_object('error', 'Guía de remisión no encontrada', 'registro', NULL);
    END IF;

    IF v_estado_sunat = 'ACEPTADO' THEN
        RETURN json_build_object(
            'error', 'No se puede editar una guía aceptada por SUNAT',
            'registro', NULL
        );
    END IF;

    SELECT
        COALESCE(p_id_modalidad_traslado, g.id_modalidad_traslado),
        CASE
            WHEN p_destinatario_nombre IS NOT NULL
                 AND NULLIF(TRIM(p_destinatario_nombre), '') IS NOT NULL THEN NULL
            WHEN p_id_destinatario IS NOT NULL THEN p_id_destinatario
            ELSE g.id_destinatario
        END,
        CASE
            WHEN p_id_destinatario IS NOT NULL THEN NULL
            WHEN p_destinatario_nombre IS NOT NULL THEN NULLIF(TRIM(p_destinatario_nombre), '')
            ELSE NULLIF(TRIM(g.destinatario_nombre), '')
        END,
        CASE
            WHEN p_id_destinatario IS NOT NULL THEN NULL
            WHEN p_destinatario_documento IS NOT NULL THEN NULLIF(TRIM(p_destinatario_documento), '')
            ELSE NULLIF(TRIM(g.destinatario_documento), '')
        END,
        CASE
            WHEN p_remitente_nombre IS NOT NULL
                 AND NULLIF(TRIM(p_remitente_nombre), '') IS NOT NULL THEN NULL
            WHEN p_id_cliente IS NOT NULL THEN p_id_cliente
            ELSE g.id_cliente
        END,
        CASE
            WHEN p_id_cliente IS NOT NULL THEN NULL
            WHEN p_remitente_nombre IS NOT NULL THEN NULLIF(TRIM(p_remitente_nombre), '')
            ELSE NULLIF(TRIM(g.remitente_nombre), '')
        END,
        CASE
            WHEN p_id_cliente IS NOT NULL THEN NULL
            WHEN p_remitente_documento IS NOT NULL THEN NULLIF(TRIM(p_remitente_documento), '')
            ELSE NULLIF(TRIM(g.remitente_documento), '')
        END,
        COALESCE(p_id_distrito_origen, g.id_distrito_origen),
        COALESCE(p_id_distrito_llegada, g.id_distrito_llegada),
        COALESCE(p_peso_bruto, g.peso_bruto)
    INTO
        v_id_modalidad,
        v_id_destinatario,
        v_destinatario_nombre,
        v_destinatario_documento,
        v_id_cliente,
        v_remitente_nombre,
        v_remitente_documento,
        v_id_distrito_origen,
        v_id_distrito_llegada,
        v_peso
    FROM gre_guia_remision g
    WHERE g.id = p_id AND g.estado = 1;

    IF v_id_destinatario IS NULL
       AND (v_destinatario_nombre IS NULL OR v_destinatario_documento IS NULL)
    THEN
        RETURN json_build_object(
            'error',
            'El destinatario es obligatorio: selecciona un cliente o ingresa nombre y documento',
            'registro',
            NULL
        );
    END IF;

    SELECT lo.descripcion INTO v_codigo_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = v_id_tipo AND lo.estado = 1;

    IF v_codigo_tipo = '31'
       AND v_id_cliente IS NULL
       AND (v_remitente_nombre IS NULL OR v_remitente_documento IS NULL)
    THEN
        RETURN json_build_object(
            'error',
            'El remitente es obligatorio en GRE transportista: selecciona un cliente o ingresa nombre y documento',
            'registro',
            NULL
        );
    END IF;

    IF v_id_distrito_origen IS NULL OR v_id_distrito_llegada IS NULL THEN
        RETURN json_build_object('error', 'Distrito de origen y llegada son obligatorios (ubigeo SUNAT)', 'registro', NULL);
    END IF;

    IF COALESCE(v_peso, 0) <= 0 THEN
        RETURN json_build_object('error', 'El peso bruto debe ser mayor a cero', 'registro', NULL);
    END IF;

    SELECT lo.descripcion INTO v_codigo_modalidad
    FROM gen_lista_opciones lo
    WHERE lo.id = v_id_modalidad AND lo.estado = 1;

    IF v_codigo_modalidad = '02'
       AND (
           COALESCE(p_id_chofer, (SELECT id_chofer FROM gre_guia_remision WHERE id = p_id)) IS NULL
           OR COALESCE(p_id_vehiculo, (SELECT id_vehiculo FROM gre_guia_remision WHERE id = p_id)) IS NULL
       )
    THEN
        RETURN json_build_object('error', 'Transporte privado requiere chofer y vehículo', 'registro', NULL);
    END IF;

    IF v_codigo_modalidad = '01'
       AND COALESCE(p_id_transportista, (SELECT id_transportista FROM gre_guia_remision WHERE id = p_id)) IS NULL
    THEN
        RETURN json_build_object('error', 'Transporte público requiere transportista', 'registro', NULL);
    END IF;

    IF p_detalles IS NOT NULL THEN
        IF json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
            RETURN json_build_object('error', 'Debe registrar al menos un ítem', 'registro', NULL);
        END IF;
    END IF;

    UPDATE gre_guia_remision
    SET
        fecha = COALESCE(p_fecha, fecha),
        fecha_traslado = COALESCE(p_fecha_traslado, fecha_traslado),
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_cliente = v_id_cliente,
        remitente_nombre = v_remitente_nombre,
        remitente_documento = v_remitente_documento,
        id_motivo_traslado = COALESCE(p_id_motivo_traslado, id_motivo_traslado),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        peso_bruto = COALESCE(p_peso_bruto, peso_bruto),
        numero_bultos = COALESCE(p_numero_bultos, numero_bultos),
        direccion_origen = COALESCE(NULLIF(TRIM(p_direccion_origen), ''), direccion_origen),
        id_distrito_origen = COALESCE(p_id_distrito_origen, id_distrito_origen),
        id_destinatario = v_id_destinatario,
        destinatario_nombre = v_destinatario_nombre,
        destinatario_documento = v_destinatario_documento,
        direccion_llegada = COALESCE(NULLIF(TRIM(p_direccion_llegada), ''), direccion_llegada),
        id_distrito_llegada = COALESCE(p_id_distrito_llegada, id_distrito_llegada),
        id_modalidad_traslado = COALESCE(p_id_modalidad_traslado, id_modalidad_traslado),
        id_transportista = CASE
            WHEN p_id_modalidad_traslado IS NOT NULL AND v_codigo_modalidad = '02' THEN NULL
            ELSE COALESCE(p_id_transportista, id_transportista)
        END,
        id_chofer = CASE
            WHEN p_id_modalidad_traslado IS NOT NULL AND v_codigo_modalidad = '01' THEN NULL
            ELSE COALESCE(p_id_chofer, id_chofer)
        END,
        id_vehiculo = CASE
            WHEN p_id_modalidad_traslado IS NOT NULL AND v_codigo_modalidad = '01' THEN NULL
            ELSE COALESCE(p_id_vehiculo, id_vehiculo)
        END,
        id_responsable = COALESCE(p_id_responsable, id_responsable),
        observaciones = CASE
            WHEN p_observaciones IS NULL THEN observaciones
            ELSE NULLIF(TRIM(p_observaciones), '')
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF p_detalles IS NOT NULL THEN
        UPDATE gre_guia_remision_detalle
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_guia_remision = p_id AND estado = 1;

        v_item := 0;
        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_item := v_item + 1;

            IF (v_detalle->>'idProducto') IS NULL
               AND (v_detalle->>'id_producto') IS NULL
               AND (v_detalle->>'idBalon') IS NULL
               AND (v_detalle->>'id_balon') IS NULL
               AND NULLIF(TRIM(COALESCE(v_detalle->>'glosa', v_detalle->>'descripcion', '')), '') IS NULL
            THEN
                RETURN json_build_object(
                    'error',
                    format('Ítem %s: indica cilindro, producto o descripción', v_item),
                    'registro',
                    NULL
                );
            END IF;

            IF COALESCE((v_detalle->>'cantidad')::NUMERIC, 0) <= 0 THEN
                RETURN json_build_object('error', format('Ítem %s: cantidad inválida', v_item), 'registro', NULL);
            END IF;

            INSERT INTO gre_guia_remision_detalle (
                id_guia_remision, item, id_producto, descripcion,
                id_unidad_medida, cantidad, id_balon, glosa,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                p_id,
                COALESCE((v_detalle->>'item')::INTEGER, v_item),
                COALESCE((v_detalle->>'idProducto')::INTEGER, (v_detalle->>'id_producto')::INTEGER),
                NULLIF(TRIM(COALESCE(v_detalle->>'descripcion', '')), ''),
                COALESCE((v_detalle->>'idUnidadMedida')::INTEGER, (v_detalle->>'id_unidad_medida')::INTEGER),
                (v_detalle->>'cantidad')::NUMERIC,
                COALESCE((v_detalle->>'idBalon')::INTEGER, (v_detalle->>'id_balon')::INTEGER),
                NULLIF(TRIM(COALESCE(v_detalle->>'glosa', '')), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );

            v_id_balon_linea := COALESCE(
                (v_detalle->>'idBalon')::INTEGER,
                (v_detalle->>'id_balon')::INTEGER
            );
            IF v_id_balon_linea IS NOT NULL THEN
                v_ids_conservar := array_append(v_ids_conservar, v_id_balon_linea);
            END IF;
        END LOOP;
    END IF;

    IF p_referencias IS NOT NULL AND json_typeof(p_referencias) = 'array' THEN
        UPDATE gre_documentos_referencia
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_guia_remision = p_id AND estado = 1;

        FOR v_ref IN SELECT value FROM json_array_elements(p_referencias)
        LOOP
            INSERT INTO gre_documentos_referencia (
                id_guia_remision, id_tipo_comprobante, serie, numero, fecha,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                p_id,
                COALESCE((v_ref->>'idTipoComprobante')::INTEGER, (v_ref->>'id_tipo_comprobante')::INTEGER),
                NULLIF(UPPER(TRIM(COALESCE(v_ref->>'serie', ''))), ''),
                NULLIF(TRIM(COALESCE(v_ref->>'numero', '')), ''),
                NULLIF(v_ref->>'fecha', '')::DATE,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    IF p_detalles IS NOT NULL THEN
        v_rev := bal_revertir_salidas_guia_remision(p_id, v_ids_conservar, p_id_usuario_auditoria);
        IF v_rev->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_rev->>'error';
        END IF;
    END IF;

    -- CY1: salidas idempotentes para cilindros presentes en la guía
    v_salidas := bal_aplicar_salidas_guia_remision(p_id, p_id_usuario_auditoria);
    IF v_salidas->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_salidas->>'error';
    END IF;

    RETURN gre_obtener_guia_remision(p_id);
END;
$function$;


-- ===== database_sql/funciones/guias-remision/gre_eliminar_guia_remision.sql =====
CREATE OR REPLACE FUNCTION gre_eliminar_guia_remision(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_orden_numero VARCHAR;
    v_rev JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM gre_guia_remision WHERE id = p_id AND estado = 1
    ) THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    SELECT es.nombre INTO v_estado_sunat
    FROM gre_guia_remision g
    LEFT JOIN gen_lista_opciones es ON g.id_estado_sunat = es.id
    WHERE g.id = p_id AND g.estado = 1;

    IF v_estado_sunat = 'ACEPTADO' THEN
        RETURN json_build_object(
            'error', 'No se puede eliminar una guía aceptada por SUNAT',
            'eliminado', FALSE,
            'id', p_id
        );
    END IF;

    SELECT rp.numero
    INTO v_orden_numero
    FROM bal_recarga_planta rp
    WHERE rp.estado = 1
      AND (rp.id_guia_salida = p_id OR rp.id_guia_retorno = p_id)
    ORDER BY rp.id
    LIMIT 1;

    IF v_orden_numero IS NOT NULL THEN
        RETURN json_build_object(
            'error',
            format(
                'No se puede eliminar: la guía está vinculada a la orden de recarga %s',
                v_orden_numero
            ),
            'eliminado',
            FALSE,
            'id',
            p_id
        );
    END IF;

    v_rev := bal_revertir_salidas_guia_remision(p_id, NULL, p_id_usuario_auditoria);
    IF v_rev->>'error' IS NOT NULL THEN
        RETURN json_build_object(
            'error', v_rev->>'error',
            'eliminado', FALSE,
            'id', p_id
        );
    END IF;

    UPDATE gre_guia_remision
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    UPDATE gre_guia_remision_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_guia_remision = p_id AND estado = 1;

    UPDATE gre_documentos_referencia
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_guia_remision = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ===== database_sql/funciones/alquileres-detalle/bal_actualizar_alquiler_detalle.sql =====
CREATE OR REPLACE FUNCTION bal_actualizar_alquiler_detalle(
    p_id INTEGER,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_alquiler INTEGER;
    v_id_balon_actual INTEGER;
    v_fecha_devolucion DATE;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_id_tipo_salida INTEGER;
    v_id_tipo_entrada INTEGER;
    v_id_tipo_doc INTEGER;
    v_id_estado_alquilado INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT ad.id_alquiler, ad.id_balon, ad.fecha_devolucion, al.id_cliente, al.id_almacen
    INTO v_id_alquiler, v_id_balon_actual, v_fecha_devolucion, v_id_cliente, v_id_almacen
    FROM bal_alquiler_detalle ad
    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
    WHERE ad.id = p_id AND ad.estado = 1;

    IF v_id_alquiler IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_balon IS NOT NULL AND p_id_balon <> v_id_balon_actual THEN
        IF v_fecha_devolucion IS NOT NULL THEN
            RETURN json_build_object(
                'error', 'No se puede cambiar el cilindro de un detalle ya devuelto',
                'registro', NULL
            );
        END IF;

        IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1) THEN
            RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE b.id = p_id_balon
              AND COALESCE(eb.nombre, '') IN ('DADO_DE_BAJA', 'ROBO')
        ) THEN
            RETURN json_build_object(
                'error', 'No se puede alquilar un cilindro dado de baja o reportado como robo',
                'registro', NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1 FROM bal_alquiler_detalle
            WHERE id_alquiler = v_id_alquiler AND id_balon = p_id_balon AND id <> p_id AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El balón ya está registrado en este alquiler', 'registro', NULL);
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_alquiler_detalle ad
            INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
            WHERE ad.id_balon = p_id_balon
              AND ad.id <> p_id
              AND ad.estado = 1
              AND ad.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro ya tiene un alquiler activo sin devolver',
                'registro', NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = p_id_balon
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro está prestado actualmente; no se puede alquilar',
                'registro', NULL
            );
        END IF;

        SELECT lo.id INTO v_id_tipo_salida
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'SALIDA_ALQUILER' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_entrada
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_DEVOLUCION' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'ALQUILER' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_estado_alquilado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'ALQUILADO' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_alquilado IS NULL OR v_id_estado_en_almacen IS NULL THEN
            RETURN json_build_object(
                'error', 'Faltan estados ALQUILADO / EN_ALMACEN en el catálogo EstadoBalon',
                'registro', NULL
            );
        END IF;

        IF v_id_almacen IS NULL THEN
            RETURN json_build_object(
                'error', 'El alquiler no tiene almacén para devolver el cilindro anterior',
                'registro', NULL
            );
        END IF;

        IF v_id_tipo_entrada IS NOT NULL THEN
            v_mov := bal_crear_movimiento(
                v_id_balon_actual,
                v_id_tipo_entrada,
                v_id_alquiler,
                v_id_tipo_doc,
                v_id_cliente,
                NULL::INTEGER,
                v_id_almacen,
                NOW()::TIMESTAMP,
                'Retorno por cambio de cilindro en alquiler'::VARCHAR,
                p_id_usuario_auditoria
            );
            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov->>'error';
            END IF;
        END IF;

        UPDATE bal_balon
        SET
            id_cliente_ubicacion = NULL,
            id_almacen = v_id_almacen,
            id_estado_balon = v_id_estado_en_almacen,
            id_estado_contenido = COALESCE(bal_id_estado_contenido('VACIO'), id_estado_contenido),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon_actual AND estado = 1;

        IF v_id_tipo_salida IS NOT NULL THEN
            v_mov := bal_crear_movimiento(
                p_id_balon,
                v_id_tipo_salida,
                v_id_alquiler,
                v_id_tipo_doc,
                v_id_cliente,
                v_id_almacen,
                NULL::INTEGER,
                NOW()::TIMESTAMP,
                'Salida por cambio de cilindro en alquiler'::VARCHAR,
                p_id_usuario_auditoria
            );
            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov->>'error';
            END IF;
        END IF;

        UPDATE bal_balon
        SET
            id_cliente_ubicacion = v_id_cliente,
            id_almacen = NULL,
            id_estado_balon = v_id_estado_alquilado,
            id_estado_contenido = COALESCE(bal_id_estado_contenido('DESCONOCIDO'), id_estado_contenido),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;

        PERFORM bal_sync_capacidad_restante(
            p_id_balon, NULL, NULL, NULL, 'CLEAR', NULL, p_id_usuario_auditoria
        );
    END IF;

    UPDATE bal_alquiler_detalle
    SET
        id_balon = COALESCE(p_id_balon, id_balon),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_alquiler_detalle(p_id);
END;
$function$;


-- ===== database_sql/funciones/alquileres-detalle/bal_eliminar_alquiler_detalle.sql =====
CREATE OR REPLACE FUNCTION bal_eliminar_alquiler_detalle(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_id_almacen INTEGER;
    v_id_alquiler INTEGER;
    v_id_cliente INTEGER;
    v_fecha_devolucion DATE;
    v_id_estado_en_almacen INTEGER;
    v_id_tipo_movimiento INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        ad.id_balon,
        ad.fecha_devolucion,
        ad.id_alquiler,
        al.id_almacen,
        al.id_cliente
    INTO
        v_id_balon,
        v_fecha_devolucion,
        v_id_alquiler,
        v_id_almacen,
        v_id_cliente
    FROM bal_alquiler_detalle ad
    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
    WHERE ad.id = p_id
      AND ad.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    UPDATE bal_alquiler_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Si el cilindro seguía pendiente de devolución, liberarlo a almacén.
    IF v_id_balon IS NOT NULL AND v_fecha_devolucion IS NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NOT NULL THEN
            SELECT lo.id INTO v_id_tipo_movimiento
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_DEVOLUCION' AND lo.estado = 1
            LIMIT 1;

            SELECT lo.id INTO v_id_tipo_documento_ref
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'ALQUILER' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_movimiento IS NOT NULL THEN
                v_mov := bal_crear_movimiento(
                    v_id_balon,
                    v_id_tipo_movimiento,
                    v_id_alquiler,
                    v_id_tipo_documento_ref,
                    v_id_cliente,
                    NULL::INTEGER,
                    v_id_almacen,
                    NOW()::TIMESTAMP,
                    'Entrada por quitar cilindro del alquiler'::VARCHAR,
                    p_id_usuario_auditoria
                );
                IF v_mov->>'error' IS NOT NULL THEN
                    RAISE EXCEPTION '%', v_mov->>'error';
                END IF;
            END IF;

            UPDATE bal_balon
            SET
                id_cliente_ubicacion = NULL,
                id_almacen = COALESCE(v_id_almacen, id_almacen),
                id_estado_balon = v_id_estado_en_almacen,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_balon
              AND estado = 1;
        END IF;
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ===== database_sql/funciones/recojos/bal_registrar_resultado_recojo.sql =====
CREATE OR REPLACE FUNCTION bal_registrar_resultado_recojo(
    p_id INTEGER,
    p_fecha_visita DATE DEFAULT NULL,
    p_id_motivo_fallo INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_detalles JSON DEFAULT '[]',
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_regulador JSON DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_estado_actual VARCHAR;
    v_fecha_visita DATE;
    v_item JSON;
    v_id_pd INTEGER;
    v_id_ad INTEGER;
    v_resultado VARCHAR;
    v_nombre_contenido VARCHAR;
    v_nueva_fecha DATE;
    v_id_almacen INTEGER;
    v_obs VARCHAR(500);
    v_id_resultado INTEGER;
    v_id_contenido INTEGER;
    v_id_prestamo_det INTEGER;
    v_id_alquiler_det INTEGER;
    v_dev JSON;
    v_cnt_total INTEGER := 0;
    v_cnt_recogido INTEGER := 0;
    v_cnt_no_recogido INTEGER := 0;
    v_cnt_extendido INTEGER := 0;
    v_cnt_efectivo INTEGER := 0;
    v_estado_header VARCHAR;
    v_id_estado_header INTEGER;
    v_id_motivo INTEGER;
    v_motivo_nombre VARCHAR;
    v_pendientes_json JSONB := '[]'::JSONB;
    v_fecha_repro DATE;
    v_nuevo JSON;
    v_id_estado_prestado INTEGER;
    v_id_balon INTEGER;
    v_repro_detalles JSONB := '[]'::JSONB;
    v_cantidad_restante NUMERIC(10,4);
    v_capacidad_tipo NUMERIC(10,4);
    v_lb_restante NUMERIC(10,4);
    v_peso_bruto_lb NUMERIC(10,4);
    v_presion_psi NUMERIC(10,4);
    v_sync JSON;
    v_tiene_regulador BOOLEAN := FALSE;
    v_reg JSONB;
    v_reg_resultado VARCHAR;
    v_reg_condicion VARCHAR;
    v_reg_nueva_fecha DATE;
    v_reg_obs VARCHAR(500);
    v_id_resultado_reg INTEGER;
    v_id_condicion_reg INTEGER;
    v_cil_pendientes INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT r.id_cliente, r.id_prestamo, r.id_alquiler, er.nombre
    INTO v_id_cliente, v_id_prestamo, v_id_alquiler, v_estado_actual
    FROM bal_recojo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    IF v_estado_actual NOT IN ('PROGRAMADO', 'EN_RUTA') THEN
        RETURN json_build_object(
            'error', 'Solo se puede registrar resultado en recojos PROGRAMADO o EN_RUTA',
            'registro', NULL
        );
    END IF;

    v_fecha_visita := COALESCE(p_fecha_visita, CURRENT_DATE);

    SELECT COUNT(*)::INTEGER INTO v_cnt_total
    FROM bal_recojo_detalle
    WHERE id_recojo = p_id AND estado = 1;

    IF v_id_alquiler IS NOT NULL THEN
        SELECT COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
        INTO v_tiene_regulador
        FROM bal_alquiler a
        WHERE a.id = v_id_alquiler AND a.estado = 1;
    END IF;

    v_reg := CASE
        WHEN p_regulador IS NULL OR p_regulador::TEXT IN ('null', '') THEN NULL
        ELSE p_regulador::JSONB
    END;

    -- Compat: recojo solo regulador enviando un ítem en detalles sin ids de cilindro
    IF v_tiene_regulador
       AND v_reg IS NULL
       AND v_cnt_total = 0
       AND jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 1
       AND COALESCE(
           NULLIF((p_detalles::JSONB -> 0)->>'idPrestamoDetalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'id_prestamo_detalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'idAlquilerDetalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'id_alquiler_detalle', '')
       ) IS NULL
    THEN
        v_reg := p_detalles::JSONB -> 0;
    END IF;

    IF v_cnt_total = 0 THEN
        IF NOT v_tiene_regulador THEN
            RETURN json_build_object(
                'error', 'Este recojo no tiene detalles ni regulador asociado',
                'registro', NULL
            );
        END IF;
    ELSE
        IF p_detalles IS NULL
           OR jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 0 THEN
            RETURN json_build_object(
                'error', 'Debe indicar el resultado de al menos un detalle',
                'registro', NULL
            );
        END IF;

        IF v_cnt_total <> jsonb_array_length(p_detalles::JSONB) THEN
            RETURN json_build_object(
                'error',
                'Debe informar resultado para todos los detalles del recojo (' || v_cnt_total || ')',
                'registro', NULL
            );
        END IF;
    END IF;

    FOR v_item IN
        SELECT * FROM jsonb_array_elements(
            CASE WHEN v_cnt_total = 0 THEN '[]'::JSONB ELSE p_detalles::JSONB END
        )
    LOOP
        v_id_pd := COALESCE(
            NULLIF(v_item->>'idPrestamoDetalle', '')::INTEGER,
            NULLIF(v_item->>'id_prestamo_detalle', '')::INTEGER
        );
        v_id_ad := COALESCE(
            NULLIF(v_item->>'idAlquilerDetalle', '')::INTEGER,
            NULLIF(v_item->>'id_alquiler_detalle', '')::INTEGER
        );
        v_resultado := UPPER(TRIM(COALESCE(
            v_item->>'resultado',
            v_item->>'nombre_resultado',
            ''
        )));
        v_nombre_contenido := NULLIF(TRIM(COALESCE(
            v_item->>'nombreEstadoContenido',
            v_item->>'nombre_estado_contenido',
            ''
        )), '');
        v_nueva_fecha := COALESCE(
            NULLIF(v_item->>'nuevaFechaRetorno', '')::DATE,
            NULLIF(v_item->>'nueva_fecha_retorno', '')::DATE
        );
        v_id_almacen := COALESCE(
            NULLIF(v_item->>'idAlmacenDestino', '')::INTEGER,
            NULLIF(v_item->>'id_almacen_destino', '')::INTEGER
        );
        v_obs := NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), '');
        v_cantidad_restante := COALESCE(
            NULLIF(v_item->>'cantidadRestante', '')::NUMERIC,
            NULLIF(v_item->>'cantidad_restante', '')::NUMERIC
        );
        v_lb_restante := COALESCE(
            NULLIF(v_item->>'lbRetorno', '')::NUMERIC,
            NULLIF(v_item->>'lb_retorno', '')::NUMERIC,
            NULLIF(v_item->>'capacidadRestanteLb', '')::NUMERIC,
            NULLIF(v_item->>'capacidad_restante_lb', '')::NUMERIC
        );
        v_peso_bruto_lb := COALESCE(
            NULLIF(v_item->>'pesoBrutoLb', '')::NUMERIC,
            NULLIF(v_item->>'peso_bruto_lb', '')::NUMERIC
        );
        v_presion_psi := COALESCE(
            NULLIF(v_item->>'presionActual', '')::NUMERIC,
            NULLIF(v_item->>'presion_actual', '')::NUMERIC,
            NULLIF(v_item->>'presionPsi', '')::NUMERIC,
            NULLIF(v_item->>'presion_psi', '')::NUMERIC
        );

        IF (v_id_pd IS NOT NULL)::INTEGER + (v_id_ad IS NOT NULL)::INTEGER <> 1 THEN
            RETURN json_build_object(
                'error', 'Cada detalle debe indicar id_prestamo_detalle o id_alquiler_detalle',
                'registro', NULL
            );
        END IF;

        IF v_id_pd IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM bal_recojo_detalle
            WHERE id_recojo = p_id AND id_prestamo_detalle = v_id_pd AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'El detalle de préstamo ' || v_id_pd || ' no pertenece a este recojo',
                'registro', NULL
            );
        END IF;

        IF v_id_ad IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM bal_recojo_detalle
            WHERE id_recojo = p_id AND id_alquiler_detalle = v_id_ad AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'El detalle de alquiler ' || v_id_ad || ' no pertenece a este recojo',
                'registro', NULL
            );
        END IF;

        IF v_resultado NOT IN ('RECOGIDO', 'NO_RECOGIDO', 'EXTENDIDO') THEN
            RETURN json_build_object(
                'error', 'Resultado inválido: ' || COALESCE(v_resultado, '(vacío)'),
                'registro', NULL
            );
        END IF;

        SELECT lo.id INTO v_id_resultado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'ResultadoRecojoDetalle' AND lo.nombre = v_resultado AND lo.estado = 1
        LIMIT 1;

        IF v_id_resultado IS NULL THEN
            RETURN json_build_object(
                'error', 'No se encontró el resultado ' || v_resultado || ' en ResultadoRecojoDetalle',
                'registro', NULL
            );
        END IF;

        v_id_contenido := NULL;
        IF v_nombre_contenido IS NOT NULL THEN
            v_id_contenido := bal_id_estado_contenido(v_nombre_contenido);
        END IF;

        IF v_resultado = 'EXTENDIDO' THEN
            v_nueva_fecha := COALESCE(v_nueva_fecha, v_fecha_visita + 1);
        END IF;

        IF v_resultado = 'RECOGIDO' THEN
            SELECT COALESCE(pd.id_balon, ad.id_balon), tb.capacidad
            INTO v_id_balon, v_capacidad_tipo
            FROM (SELECT 1) dummy
            LEFT JOIN bal_prestamo_detalle pd
                ON pd.id = v_id_pd AND pd.estado = 1
            LEFT JOIN bal_alquiler_detalle ad
                ON ad.id = v_id_ad AND ad.estado = 1
            LEFT JOIN bal_balon b
                ON b.id = COALESCE(pd.id_balon, ad.id_balon) AND b.estado = 1
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon;

            IF v_cantidad_restante IS NULL THEN
                IF UPPER(COALESCE(v_nombre_contenido, 'VACIO')) = 'VACIO' THEN
                    v_cantidad_restante := 0;
                ELSIF UPPER(COALESCE(v_nombre_contenido, '')) = 'LLENO' THEN
                    v_cantidad_restante := v_capacidad_tipo;
                END IF;
            ELSIF v_cantidad_restante < 0 THEN
                RETURN json_build_object(
                    'error', 'La cantidad restante no puede ser negativa',
                    'registro', NULL
                );
            ELSIF v_capacidad_tipo IS NOT NULL AND v_cantidad_restante > v_capacidad_tipo THEN
                RETURN json_build_object(
                    'error',
                    'La cantidad restante (' || v_cantidad_restante
                        || ') supera la capacidad del cilindro (' || v_capacidad_tipo || ')',
                    'registro', NULL
                );
            END IF;

            -- Inferir contenido si solo enviaron medida
            IF v_nombre_contenido IS NULL AND v_cantidad_restante IS NOT NULL THEN
                IF v_cantidad_restante <= 0 THEN
                    v_nombre_contenido := 'VACIO';
                ELSIF v_capacidad_tipo IS NOT NULL AND v_cantidad_restante >= v_capacidad_tipo THEN
                    v_nombre_contenido := 'LLENO';
                ELSE
                    v_nombre_contenido := 'DESCONOCIDO';
                END IF;
                v_id_contenido := bal_id_estado_contenido(v_nombre_contenido);
            END IF;
        ELSE
            v_cantidad_restante := NULL;
            v_id_balon := NULL;
        END IF;

        UPDATE bal_recojo_detalle
        SET
            id_resultado = v_id_resultado,
            id_estado_contenido = COALESCE(v_id_contenido, id_estado_contenido),
            cantidad_restante = CASE
                WHEN v_resultado = 'RECOGIDO' THEN v_cantidad_restante
                ELSE cantidad_restante
            END,
            nueva_fecha_retorno = CASE
                WHEN v_resultado = 'EXTENDIDO' THEN v_nueva_fecha
                ELSE nueva_fecha_retorno
            END,
            id_almacen_destino = COALESCE(v_id_almacen, id_almacen_destino),
            observacion = COALESCE(v_obs, observacion),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_recojo = p_id
          AND estado = 1
          AND (
              (v_id_pd IS NOT NULL AND id_prestamo_detalle = v_id_pd)
              OR (v_id_ad IS NOT NULL AND id_alquiler_detalle = v_id_ad)
          );

        IF v_resultado = 'RECOGIDO' THEN
            v_cnt_recogido := v_cnt_recogido + 1;
            IF v_id_pd IS NOT NULL THEN
                v_dev := bal_devolver_prestamo_detalle(
                    v_id_pd,
                    v_fecha_visita,
                    v_id_almacen,
                    p_id_usuario_auditoria,
                    COALESCE(v_nombre_contenido, 'VACIO'),
                    v_obs
                );
            ELSE
                v_dev := bal_devolver_alquiler_detalle(
                    v_id_ad,
                    v_fecha_visita,
                    v_id_almacen,
                    p_id_usuario_auditoria
                );
            END IF;
            IF v_dev->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_dev->>'error', 'registro', NULL);
            END IF;

            -- Residual dual: prioridad bruto lb > lb residual > m³; PSI opcional
            IF v_id_balon IS NOT NULL AND (
                v_peso_bruto_lb IS NOT NULL
                OR v_lb_restante IS NOT NULL
                OR v_cantidad_restante IS NOT NULL
            ) THEN
                IF v_peso_bruto_lb IS NOT NULL THEN
                    v_sync := bal_sync_capacidad_restante(
                        v_id_balon,
                        NULL,
                        NULL,
                        v_presion_psi,
                        'FROM_BRUTO_LB',
                        v_peso_bruto_lb,
                        p_id_usuario_auditoria
                    );
                ELSIF v_lb_restante IS NOT NULL THEN
                    v_sync := bal_sync_capacidad_restante(
                        v_id_balon,
                        NULL,
                        v_lb_restante,
                        v_presion_psi,
                        'FROM_LB',
                        NULL,
                        p_id_usuario_auditoria
                    );
                ELSE
                    v_sync := bal_sync_capacidad_restante(
                        v_id_balon,
                        v_cantidad_restante,
                        NULL,
                        v_presion_psi,
                        'FROM_M3',
                        NULL,
                        p_id_usuario_auditoria
                    );
                END IF;

                IF COALESCE((v_sync->>'ok')::BOOLEAN, FALSE) IS NOT TRUE THEN
                    RETURN json_build_object(
                        'error',
                        COALESCE(v_sync->>'error', 'No se pudo sincronizar capacidad residual'),
                        'registro',
                        NULL
                    );
                END IF;
            END IF;
        ELSIF v_resultado = 'EXTENDIDO' THEN
            v_cnt_extendido := v_cnt_extendido + 1;
            IF v_id_pd IS NOT NULL THEN
                SELECT pd.id_prestamo, pd.id_balon
                INTO v_id_prestamo_det, v_id_balon
                FROM bal_prestamo_detalle pd
                WHERE pd.id = v_id_pd AND pd.estado = 1;

                UPDATE bal_prestamo_detalle
                SET
                    fecha_vencimiento = v_nueva_fecha,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_pd AND estado = 1;

                UPDATE bal_prestamo
                SET
                    fecha_retorno_pactada = v_nueva_fecha,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_prestamo_det AND estado = 1;
            ELSE
                SELECT ad.id_alquiler, ad.id_balon
                INTO v_id_alquiler_det, v_id_balon
                FROM bal_alquiler_detalle ad
                WHERE ad.id = v_id_ad AND ad.estado = 1;

                UPDATE bal_alquiler
                SET
                    fecha_fin_pactada = v_nueva_fecha,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_alquiler_det AND estado = 1;
            END IF;

            SELECT lo.id INTO v_id_estado_prestado
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoBalon'
              AND lo.nombre = CASE WHEN v_id_ad IS NOT NULL THEN 'ALQUILADO' ELSE 'PRESTADO_CLIENTE' END
              AND lo.estado = 1
            LIMIT 1;

            IF v_id_balon IS NOT NULL AND v_id_estado_prestado IS NOT NULL THEN
                UPDATE bal_balon b
                SET
                    id_estado_balon = v_id_estado_prestado,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                FROM gen_lista_opciones eb
                WHERE b.id = v_id_balon
                  AND b.estado = 1
                  AND eb.id = b.id_estado_balon
                  AND eb.nombre = 'POR_RECOGER';
            END IF;

            v_pendientes_json := v_pendientes_json || jsonb_build_array(
                jsonb_build_object(
                    'id_prestamo_detalle', v_id_pd,
                    'id_alquiler_detalle', v_id_ad,
                    'nueva_fecha_retorno', v_nueva_fecha,
                    'observacion', v_obs
                )
            );
        ELSE
            v_cnt_no_recogido := v_cnt_no_recogido + 1;
            v_pendientes_json := v_pendientes_json || jsonb_build_array(
                jsonb_build_object(
                    'id_prestamo_detalle', v_id_pd,
                    'id_alquiler_detalle', v_id_ad,
                    'nueva_fecha_retorno', v_fecha_visita + 1,
                    'observacion', v_obs,
                    'no_recogido', TRUE
                )
            );
        END IF;
    END LOOP;

    -- Regulador / accesorio (independiente de cilindros)
    IF v_tiene_regulador THEN
        IF v_reg IS NULL OR COALESCE(NULLIF(TRIM(COALESCE(
            v_reg->>'resultado', v_reg->>'nombre_resultado', ''
        )), ''), '') = '' THEN
            RETURN json_build_object(
                'error', 'Debe indicar el resultado del regulador/accesorio',
                'registro', NULL
            );
        END IF;

        v_reg_resultado := UPPER(TRIM(COALESCE(
            v_reg->>'resultado',
            v_reg->>'nombre_resultado',
            ''
        )));
        v_reg_condicion := UPPER(TRIM(COALESCE(
            v_reg->>'condicion',
            v_reg->>'nombreCondicion',
            v_reg->>'nombre_condicion',
            ''
        )));
        v_reg_nueva_fecha := COALESCE(
            NULLIF(v_reg->>'nuevaFechaRetorno', '')::DATE,
            NULLIF(v_reg->>'nueva_fecha_retorno', '')::DATE
        );
        v_reg_obs := NULLIF(TRIM(COALESCE(v_reg->>'observacion', '')), '');

        IF v_reg_resultado NOT IN ('RECOGIDO', 'NO_RECOGIDO', 'EXTENDIDO') THEN
            RETURN json_build_object(
                'error', 'Resultado de regulador inválido: ' || COALESCE(v_reg_resultado, '(vacío)'),
                'registro', NULL
            );
        END IF;

        SELECT lo.id INTO v_id_resultado_reg
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'ResultadoRecojoDetalle'
          AND lo.nombre = v_reg_resultado
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_resultado_reg IS NULL THEN
            RETURN json_build_object(
                'error', 'No se encontró el resultado ' || v_reg_resultado || ' en ResultadoRecojoDetalle',
                'registro', NULL
            );
        END IF;

        IF v_reg_resultado = 'RECOGIDO' THEN
            IF v_reg_condicion NOT IN ('BUENO', 'PARA_REPARAR') THEN
                RETURN json_build_object(
                    'error', 'Debe indicar si el regulador está BUENO o PARA_REPARAR',
                    'registro', NULL
                );
            END IF;

            SELECT lo.id INTO v_id_condicion_reg
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'CondicionRegulador'
              AND lo.nombre = v_reg_condicion
              AND lo.estado = 1
            LIMIT 1;

            IF v_id_condicion_reg IS NULL THEN
                RETURN json_build_object(
                    'error', 'No se encontró la condición ' || v_reg_condicion || ' en CondicionRegulador',
                    'registro', NULL
                );
            END IF;

            v_cnt_recogido := v_cnt_recogido + 1;

            v_dev := bal_devolver_regulador_alquiler(
                v_id_alquiler,
                v_fecha_visita,
                v_reg_condicion,
                v_reg_obs,
                p_id,
                p_id_usuario_auditoria
            );

            IF v_dev->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_dev->>'error', 'registro', NULL);
            END IF;
        ELSIF v_reg_resultado = 'EXTENDIDO' THEN
            v_cnt_extendido := v_cnt_extendido + 1;
            v_reg_nueva_fecha := COALESCE(v_reg_nueva_fecha, v_fecha_visita + 1);

            UPDATE bal_alquiler
            SET
                fecha_fin_pactada = v_reg_nueva_fecha,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_alquiler AND estado = 1;

            v_pendientes_json := v_pendientes_json || jsonb_build_array(
                jsonb_build_object(
                    'solo_regulador', TRUE,
                    'nueva_fecha_retorno', v_reg_nueva_fecha,
                    'observacion', v_reg_obs
                )
            );
        ELSE
            v_cnt_no_recogido := v_cnt_no_recogido + 1;
            v_pendientes_json := v_pendientes_json || jsonb_build_array(
                jsonb_build_object(
                    'solo_regulador', TRUE,
                    'nueva_fecha_retorno', v_fecha_visita + 1,
                    'observacion', v_reg_obs,
                    'no_recogido', TRUE
                )
            );
        END IF;
    END IF;

    v_cnt_efectivo := v_cnt_total + CASE WHEN v_tiene_regulador THEN 1 ELSE 0 END;

    IF v_cnt_efectivo = 0 THEN
        RETURN json_build_object(
            'error', 'No hay ítems para registrar en este recojo',
            'registro', NULL
        );
    END IF;

    IF v_cnt_recogido = v_cnt_efectivo THEN
        v_estado_header := 'EXITOSO';
    ELSIF v_cnt_no_recogido = v_cnt_efectivo THEN
        v_estado_header := 'FALLIDO';
    ELSE
        v_estado_header := 'REPROGRAMADO';
    END IF;

    SELECT lo.id INTO v_id_estado_header
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = v_estado_header AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_header IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado ' || v_estado_header || ' en EstadoRecojo',
            'registro', NULL
        );
    END IF;

    v_id_motivo := p_id_motivo_fallo;
    IF v_id_motivo IS NOT NULL THEN
        SELECT lo.nombre INTO v_motivo_nombre
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE lo.id = v_id_motivo
          AND l.nombre = 'MotivoFalloRecojo'
          AND lo.estado = 1;

        IF v_motivo_nombre IS NULL THEN
            RETURN json_build_object(
                'error', 'El motivo de fallo no existe o no pertenece a MotivoFalloRecojo',
                'registro', NULL
            );
        END IF;
    END IF;

    IF v_estado_header = 'FALLIDO' AND v_id_motivo IS NULL THEN
        RETURN json_build_object(
            'error', 'Debe indicar el motivo de fallo cuando el recojo es FALLIDO',
            'registro', NULL
        );
    END IF;

    UPDATE bal_recojo
    SET
        fecha_visita = v_fecha_visita,
        id_estado = v_id_estado_header,
        id_motivo_fallo = CASE
            WHEN v_estado_header IN ('FALLIDO', 'REPROGRAMADO') AND v_cnt_no_recogido > 0
                THEN COALESCE(v_id_motivo, id_motivo_fallo)
            WHEN v_estado_header = 'FALLIDO' THEN v_id_motivo
            ELSE id_motivo_fallo
        END,
        observacion = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion),
        id_resultado_regulador = COALESCE(v_id_resultado_reg, id_resultado_regulador),
        id_condicion_regulador = COALESCE(v_id_condicion_reg, id_condicion_regulador),
        nueva_fecha_retorno_regulador = CASE
            WHEN v_reg_resultado = 'EXTENDIDO' THEN v_reg_nueva_fecha
            ELSE nueva_fecha_retorno_regulador
        END,
        observacion_regulador = COALESCE(v_reg_obs, observacion_regulador),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- Cerrar alquiler si ya no quedan cilindros ni regulador pendientes
    IF v_id_alquiler IS NOT NULL AND v_reg_resultado = 'RECOGIDO' THEN
        SELECT COUNT(*)::INTEGER INTO v_cil_pendientes
        FROM bal_alquiler_detalle ad
        WHERE ad.id_alquiler = v_id_alquiler
          AND ad.estado = 1
          AND ad.fecha_devolucion IS NULL;

        IF v_cil_pendientes = 0 THEN
            SELECT lo.id INTO v_id_estado_prestado
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_estado_prestado IS NOT NULL THEN
                v_dev := bal_actualizar_alquiler(
                    v_id_alquiler,
                    NULL::VARCHAR,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    NULL::DATE,
                    NULL::DATE,
                    v_fecha_visita,
                    NULL::NUMERIC,
                    NULL::NUMERIC,
                    v_id_estado_prestado,
                    NULL::VARCHAR,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    p_id_usuario_auditoria
                );

                IF v_dev->>'error' IS NOT NULL THEN
                    RETURN json_build_object('error', v_dev->>'error', 'registro', NULL);
                END IF;
            END IF;
        END IF;
    END IF;

    IF v_estado_header = 'REPROGRAMADO'
       AND jsonb_array_length(v_pendientes_json) > 0 THEN
        SELECT MIN((elem->>'nueva_fecha_retorno')::DATE)
        INTO v_fecha_repro
        FROM jsonb_array_elements(v_pendientes_json) elem;

        v_fecha_repro := COALESCE(v_fecha_repro, v_fecha_visita + 1);

        SELECT COALESCE(
            jsonb_agg(
                CASE
                    WHEN NULLIF(elem->>'id_prestamo_detalle', '') IS NOT NULL THEN
                        jsonb_build_object(
                            'id_prestamo_detalle', (elem->>'id_prestamo_detalle')::INTEGER,
                            'observacion', elem->>'observacion'
                        )
                    WHEN NULLIF(elem->>'id_alquiler_detalle', '') IS NOT NULL THEN
                        jsonb_build_object(
                            'id_alquiler_detalle', (elem->>'id_alquiler_detalle')::INTEGER,
                            'observacion', elem->>'observacion'
                        )
                    ELSE NULL
                END
            ) FILTER (WHERE COALESCE(elem->>'solo_regulador', 'false') <> 'true'
                      AND (
                          NULLIF(elem->>'id_prestamo_detalle', '') IS NOT NULL
                          OR NULLIF(elem->>'id_alquiler_detalle', '') IS NOT NULL
                      )),
            '[]'::JSONB
        )
        INTO v_repro_detalles
        FROM jsonb_array_elements(v_pendientes_json) elem;

        v_nuevo := bal_crear_recojo(
            v_id_cliente,
            v_id_prestamo,
            v_id_alquiler,
            v_fecha_repro,
            NULL::TIME,
            NULL::INTEGER,
            'Reprogramado desde recojo #' || p_id,
            COALESCE(v_repro_detalles, '[]'::JSONB)::JSON,
            p_id_usuario_auditoria
        );

        IF v_nuevo->>'error' IS NOT NULL THEN
            RETURN json_build_object(
                'error',
                'Resultado registrado pero no se pudo reprogramar: ' || (v_nuevo->>'error'),
                'registro', NULL
            );
        END IF;
    END IF;

    RETURN bal_obtener_recojo(p_id);
END;
$function$;


-- ===== database_sql/funciones/recojos/bal_eliminar_recojo.sql =====
CREATE OR REPLACE FUNCTION bal_eliminar_recojo(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_estado_prestado INTEGER;
    v_id_estado_alquilado INTEGER;
    v_det RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre
    INTO v_estado
    FROM bal_recojo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'Recojo no encontrado');
    END IF;

    IF v_estado NOT IN ('PROGRAMADO', 'EN_RUTA', 'CANCELADO') THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'Solo se pueden eliminar recojos PROGRAMADO, EN_RUTA o CANCELADO'
        );
    END IF;

    SELECT lo.id INTO v_id_estado_prestado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_alquilado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'ALQUILADO' AND lo.estado = 1
    LIMIT 1;

    -- POR_RECOGER → PRESTADO o ALQUILADO según el origen del detalle.
    IF v_id_estado_prestado IS NOT NULL THEN
        FOR v_det IN
            SELECT pd.id_balon
            FROM bal_recojo_detalle rd
            INNER JOIN bal_prestamo_detalle pd ON pd.id = rd.id_prestamo_detalle AND pd.estado = 1
            INNER JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
            INNER JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE rd.id_recojo = p_id
              AND rd.estado = 1
              AND pd.fecha_devolucion IS NULL
              AND eb.nombre = 'POR_RECOGER'
        LOOP
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_estado_prestado,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_det.id_balon;
        END LOOP;
    END IF;

    IF v_id_estado_alquilado IS NOT NULL THEN
        FOR v_det IN
            SELECT ad.id_balon
            FROM bal_recojo_detalle rd
            INNER JOIN bal_alquiler_detalle ad ON ad.id = rd.id_alquiler_detalle AND ad.estado = 1
            INNER JOIN bal_balon b ON b.id = ad.id_balon AND b.estado = 1
            INNER JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE rd.id_recojo = p_id
              AND rd.estado = 1
              AND ad.fecha_devolucion IS NULL
              AND eb.nombre = 'POR_RECOGER'
        LOOP
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_estado_alquilado,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_det.id_balon;
        END LOOP;
    END IF;

    UPDATE bal_recojo_detalle
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_recojo = p_id AND estado = 1;

    UPDATE bal_recojo
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ===== database_sql/funciones/movimientos-recarga/bal_crear_recarga_cliente.sql =====
DROP FUNCTION IF EXISTS bal_crear_recarga_cliente(
    INTEGER, INTEGER, INTEGER, NUMERIC, NUMERIC, INTEGER, VARCHAR, NUMERIC,
    INTEGER, INTEGER, VARCHAR, INTEGER, INTEGER
);

CREATE OR REPLACE FUNCTION bal_crear_recarga_cliente(
    p_id_cliente INTEGER,
    p_id_balon INTEGER,
    p_id_producto INTEGER,
    p_precio_unitario NUMERIC,
    p_cantidad NUMERIC DEFAULT 1,
    p_id_tipo_comprobante INTEGER DEFAULT NULL,
    p_serie VARCHAR DEFAULT 'B001',
    p_capacidad NUMERIC DEFAULT NULL,
    p_id_medio_pago INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_balon_origen INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_id_condicion_pago INTEGER DEFAULT NULL,
    p_fecha_vencimiento DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_id_tipo_recarga INTEGER;
    v_id_tipo_comprobante INTEGER;
    v_id_tipo_venta INTEGER;
    v_id_afectacion_igv INTEGER;
    v_id_tipo_movimiento INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_id_moneda INTEGER;
    v_id_tipo_operacion_sunat INTEGER;
    v_detalles JSON;
    v_comprobante_result JSON;
    v_id_comprobante INTEGER;
    v_serie_comprobante VARCHAR;
    v_numero_comprobante VARCHAR;
    v_id_recarga INTEGER;
    v_recarga JSON;
    v_comprobante JSON;
    v_capacidad NUMERIC;
    v_capacidad_destino NUMERIC;
    v_producto_nombre VARCHAR;
    v_consumo JSON;
    v_asignacion JSON;
    v_origenes JSON;
    v_id_balon_origen_principal INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := CURRENT_DATE;

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'El balón es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_balon_origen IS NOT NULL AND p_id_balon_origen = p_id_balon THEN
        RETURN json_build_object(
            'error',
            'El balón origen no puede ser el mismo que el destino',
            'registro',
            NULL
        );
    END IF;

    IF p_id_producto IS NULL THEN
        RETURN json_build_object('error', 'El producto (gas) es obligatorio', 'registro', NULL);
    END IF;

    IF p_precio_unitario IS NULL OR p_precio_unitario < 0 THEN
        RETURN json_build_object('error', 'El precio unitario es obligatorio', 'registro', NULL);
    END IF;

    IF COALESCE(p_cantidad, 0) <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoRecarga' AND lo.nombre = 'CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF p_id_tipo_comprobante IS NOT NULL THEN
        v_id_tipo_comprobante := p_id_tipo_comprobante;
    ELSE
        SELECT lo.id INTO v_id_tipo_comprobante
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoComprobante' AND lo.nombre = 'BOLETA' AND lo.estado = 1
        LIMIT 1;
    END IF;

    IF v_id_tipo_comprobante IS NULL THEN
        RETURN json_build_object('error', 'No se encontró el tipo de comprobante BOLETA en catálogos', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_venta
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoVenta' AND lo.nombre = 'VENTA_GAS' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_afectacion_igv
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'AfectacionIgv' AND lo.descripcion = '10' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_movimiento
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'RECARGA_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_movimiento IS NULL THEN
        SELECT lo.id INTO v_id_tipo_movimiento
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_LLENADO' AND lo.estado = 1
        LIMIT 1;
    END IF;

    SELECT lo.id INTO v_id_tipo_documento_ref
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_moneda
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'Moneda' AND lo.nombre = 'PEN' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_operacion_sunat
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoOperacionSunat' AND lo.descripcion = '0101' AND lo.estado = 1
    LIMIT 1;

    SELECT nombre INTO v_producto_nombre
    FROM pro_producto
    WHERE id = p_id_producto;

    SELECT COALESCE(tb.capacidad, p_capacidad, p_cantidad, 0)
    INTO v_capacidad_destino
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon;

    v_capacidad := COALESCE(NULLIF(p_capacidad, 0), v_capacidad_destino, p_cantidad);

    IF v_capacidad <= 0 THEN
        RETURN json_build_object(
            'error',
            'No se pudo determinar la capacidad a recargar',
            'registro',
            NULL
        );
    END IF;

    v_asignacion := bal_asignar_origenes_recarga(
        p_id_producto,
        v_capacidad,
        p_id_almacen,
        p_id_balon_origen
    );

    IF v_asignacion->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_asignacion->>'error', 'registro', NULL);
    END IF;

    v_origenes := v_asignacion->'origenes';
    v_id_balon_origen_principal := (v_asignacion->>'id_balon_origen_principal')::INTEGER;

    v_detalles := json_build_array(
        json_build_object(
            'id_producto', p_id_producto,
            'cantidad', p_cantidad,
            'precio_unitario', p_precio_unitario,
            'descuento', 0,
            'porcentaje_igv', 18,
            'id_afectacion_igv', v_id_afectacion_igv,
            'descripcion', 'Recarga ' || COALESCE(v_producto_nombre, 'gas'),
            'id_balon', p_id_balon,
            'capacidad_cilindro', v_capacidad
        )
    );

    v_comprobante_result := ven_crear_comprobante(
        v_id_tipo_comprobante,
        COALESCE(NULLIF(TRIM(p_serie), ''), 'B001'),
        NULL,
        v_fecha,
        p_id_cliente,
        v_detalles,
        v_id_tipo_operacion_sunat,
        NULL,
        NULL,
        NULL,
        v_id_tipo_venta,
        p_fecha_vencimiento,
        3.5,
        NULL,
        p_id_almacen,
        p_id_condicion_pago,
        v_id_moneda,
        p_id_medio_pago,
        'Recarga de balón',
        p_observacion,
        NULL,
        NULL,
        NULL,
        NULL,
        p_id_usuario_auditoria,
        'recarga'
    );

    IF v_comprobante_result->>'error' IS NOT NULL THEN
        RETURN json_build_object(
            'error', v_comprobante_result->>'error',
            'registro', NULL
        );
    END IF;

    v_comprobante := v_comprobante_result->'registro';
    v_id_comprobante := (v_comprobante->>'id')::INTEGER;
    v_serie_comprobante := v_comprobante->>'serie';
    v_numero_comprobante := v_comprobante->>'numero';

    v_consumo := bal_consumir_capacidad_origenes_recarga(
        v_origenes,
        p_id_usuario_auditoria
    );

    IF v_consumo->>'error' IS NOT NULL THEN
        -- Abortar para revertir el comprobante ya creado en la misma transacción.
        RAISE EXCEPTION '%', v_consumo->>'error';
    END IF;

    INSERT INTO bal_movimiento_recarga (
        fecha_salida_almacen,
        id_balon,
        id_balon_origen,
        id_cliente,
        id_tipo_recarga,
        id_producto,
        capacidad,
        serie_factura,
        numero_factura,
        id_comprobante,
        fecha_llegada_almacen,
        observacion,
        id_almacen,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        v_fecha,
        p_id_balon,
        v_id_balon_origen_principal,
        p_id_cliente,
        v_id_tipo_recarga,
        p_id_producto,
        v_capacidad,
        v_serie_comprobante,
        v_numero_comprobante,
        v_id_comprobante,
        v_fecha,
        CASE
            WHEN COALESCE(v_asignacion->>'etiqueta', '') <> '' THEN
                TRIM(BOTH ' ' FROM CONCAT_WS(
                    ' | ',
                    NULLIF(TRIM(COALESCE(p_observacion, '')), ''),
                    'Orígenes: ' || (v_asignacion->>'etiqueta')
                ))
            ELSE p_observacion
        END,
        p_id_almacen,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_recarga;

    INSERT INTO bal_movimiento_recarga_origen (
        id_movimiento_recarga,
        id_balon,
        cantidad,
        orden,
        id_usuario_creacion
    )
    SELECT
        v_id_recarga,
        (o->>'id_balon')::INTEGER,
        (o->>'cantidad')::NUMERIC,
        COALESCE((o->>'orden')::INTEGER, 1),
        p_id_usuario_auditoria
    FROM json_array_elements(v_origenes) o;

    IF v_id_tipo_movimiento IS NOT NULL THEN
        INSERT INTO bal_movimiento (
            id_balon,
            id_tipo_movimiento,
            id_documento_ref,
            id_tipo_documento_ref,
            id_cliente,
            id_almacen_destino,
            fecha_movimiento,
            observacion,
            id_usuario_creacion,
            id_usuario_modificacion
        )
        VALUES (
            p_id_balon,
            v_id_tipo_movimiento,
            v_id_recarga,
            v_id_tipo_documento_ref,
            p_id_cliente,
            p_id_almacen,
            NOW(),
            COALESCE(p_observacion, 'Recarga cliente'),
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END IF;

    -- Sale lleno del mostrador, pero fuera de planta el residual deja de ser confiable.
    UPDATE bal_balon
    SET
        id_producto_gas = p_id_producto,
        id_cliente_ubicacion = p_id_cliente,
        id_almacen = NULL,
        presion_actual = NULL,
        id_estado_balon = COALESCE(
            (
                SELECT lo.id
                FROM gen_lista_opciones lo
                INNER JOIN gen_lista l ON lo.id_lista = l.id
                WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_PODER_CLIENTE' AND lo.estado = 1
                LIMIT 1
            ),
            id_estado_balon
        ),
        id_estado_contenido = COALESCE(bal_id_estado_contenido('DESCONOCIDO'), id_estado_contenido),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    PERFORM bal_sync_capacidad_restante(
        p_id_balon,
        NULL,
        NULL,
        NULL,
        'CLEAR',
        NULL,
        p_id_usuario_auditoria
    );

    v_recarga := bal_obtener_movimiento_recarga(v_id_recarga);

    RETURN json_build_object(
        'registro', json_build_object(
            'recarga', v_recarga->'registro',
            'comprobante', v_comprobante
        )
    );
END;
$function$;


-- ===== database_sql/funciones/mantenimientos/bal_eliminar_mantenimiento.sql =====
CREATE OR REPLACE FUNCTION bal_eliminar_mantenimiento(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_comprobante_venta INTEGER;
    v_id_comprobante_compra INTEGER;
    v_id_balon INTEGER;
    v_id_almacen INTEGER;
    v_nombre_estado VARCHAR;
    v_id_estado_en_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        m.id_comprobante_venta,
        m.id_comprobante_compra,
        m.id_balon,
        em.nombre,
        b.id_almacen
    INTO
        v_id_comprobante_venta,
        v_id_comprobante_compra,
        v_id_balon,
        v_nombre_estado,
        v_id_almacen
    FROM bal_mantenimiento m
    LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
    LEFT JOIN bal_balon b ON b.id = m.id_balon AND b.estado = 1
    WHERE m.id = p_id AND m.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_id_comprobante_venta IS NOT NULL OR v_id_comprobante_compra IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el mantenimiento porque tiene un comprobante vinculado'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_balon_ph_historial WHERE id_mantenimiento = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el mantenimiento porque tiene historial de P.H. asociado'
        );
    END IF;

    UPDATE bal_mantenimiento
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Si no estaba finalizado, restaurar custodia previa (alquiler / préstamo / almacén).
    IF v_id_balon IS NOT NULL AND UPPER(COALESCE(v_nombre_estado, '')) <> 'FINALIZADO' THEN
        IF EXISTS (
            SELECT 1
            FROM bal_alquiler_detalle ad
            INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
            WHERE ad.id_balon = v_id_balon
              AND ad.estado = 1
              AND ad.fecha_devolucion IS NULL
        ) THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'ALQUILADO' AND lo.estado = 1
            LIMIT 1;

            UPDATE bal_balon b
            SET
                id_estado_balon = COALESCE(v_id_estado_en_almacen, b.id_estado_balon),
                id_almacen = NULL,
                id_cliente_ubicacion = (
                    SELECT al.id_cliente
                    FROM bal_alquiler_detalle ad
                    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler
                    WHERE ad.id_balon = v_id_balon
                      AND ad.estado = 1
                      AND ad.fecha_devolucion IS NULL
                    ORDER BY ad.id DESC
                    LIMIT 1
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE b.id = v_id_balon
              AND b.estado = 1
              AND EXISTS (
                  SELECT 1 FROM gen_lista_opciones eb
                  WHERE eb.id = b.id_estado_balon
                    AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
              );
        ELSIF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = v_id_balon
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
        ) THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
            LIMIT 1;

            UPDATE bal_balon b
            SET
                id_estado_balon = COALESCE(v_id_estado_en_almacen, b.id_estado_balon),
                id_almacen = NULL,
                id_cliente_ubicacion = (
                    SELECT p2.id_cliente
                    FROM bal_prestamo_detalle pd
                    INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo
                    WHERE pd.id_balon = v_id_balon
                      AND pd.estado = 1
                      AND pd.fecha_devolucion IS NULL
                    ORDER BY pd.id DESC
                    LIMIT 1
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE b.id = v_id_balon
              AND b.estado = 1
              AND EXISTS (
                  SELECT 1 FROM gen_lista_opciones eb
                  WHERE eb.id = b.id_estado_balon
                    AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
              );
        ELSE
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
            LIMIT 1;

            IF v_id_estado_en_almacen IS NOT NULL THEN
                UPDATE bal_balon
                SET
                    id_estado_balon = v_id_estado_en_almacen,
                    id_almacen = COALESCE(id_almacen, v_id_almacen),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_balon
                  AND estado = 1
                  AND EXISTS (
                      SELECT 1
                      FROM gen_lista_opciones eb
                      WHERE eb.id = bal_balon.id_estado_balon
                        AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
                  )
                  AND NOT EXISTS (
                      SELECT 1
                      FROM bal_mantenimiento m2
                      LEFT JOIN gen_lista_opciones em2 ON em2.id = m2.id_estado
                      WHERE m2.id_balon = v_id_balon
                        AND m2.id <> p_id
                        AND m2.estado = 1
                        AND UPPER(COALESCE(em2.nombre, '')) <> 'FINALIZADO'
                  );
            END IF;
        END IF;
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ===== database_sql/funciones/finanzas/fin_registrar_pago.sql =====
-- Registra un pago/cobranza sobre una cuenta financiera y recalcula su saldo.
-- No crea cuentas: solo aplica pagos a cuentas ya existentes.
-- Los pagos de préstamos con cuotas se aplican a la CUOTA HIJA correspondiente
-- (no a la cabecera del plan).

DROP FUNCTION IF EXISTS fin_registrar_pago(INT, VARCHAR, DATE, NUMERIC, INT, VARCHAR, VARCHAR, INT);
DROP FUNCTION IF EXISTS fin_registrar_pago(INT, VARCHAR, DATE, NUMERIC, INT, INT, VARCHAR, VARCHAR, VARCHAR, INT);

CREATE OR REPLACE FUNCTION fin_registrar_pago(
    p_id_cuenta          INT,
    p_tipo               VARCHAR,
    p_fecha_pago         DATE    DEFAULT NULL,
    p_monto              NUMERIC DEFAULT NULL,
    p_id_medio_pago      INT     DEFAULT NULL,
    p_id_cuenta_bancaria INT     DEFAULT NULL,
    p_numero_operacion   VARCHAR DEFAULT NULL,
    p_referencia         VARCHAR DEFAULT NULL,
    p_observacion        VARCHAR DEFAULT NULL,
    p_id_usuario         INT     DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_tipo     INT;
    v_cuenta      fin_cuenta%ROWTYPE;
    v_saldo       NUMERIC(12,2);
    v_monto       NUMERIC(12,2);
    v_nuevo_saldo NUMERIC(12,2);
    v_id_pago     INT;
    v_err_caja TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_err_caja := fin_caja_assert_abierta(COALESCE(p_fecha_pago, CURRENT_DATE), NULL);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error', v_err_caja);
    END IF;

    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera'
      AND glo.nombre = UPPER(p_tipo)
    LIMIT 1;

    SELECT * INTO v_cuenta FROM fin_cuenta WHERE id = p_id_cuenta AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La cuenta no existe o está inactiva');
    END IF;

    IF v_id_tipo IS NOT NULL AND v_cuenta.id_tipo_cuenta <> v_id_tipo THEN
        RETURN json_build_object('registro', NULL, 'error', 'La cuenta no corresponde al tipo indicado');
    END IF;

    -- No permitir pagar directamente contra la cabecera de un plan de cuotas
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

    -- La fecha de pago no puede ser anterior a la emisión de la cuenta
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
        referencia, observacion, id_usuario_creacion
    ) VALUES (
        p_id_cuenta,
        COALESCE(p_fecha_pago, CURRENT_DATE),
        v_monto,
        p_id_medio_pago,
        p_id_cuenta_bancaria,
        NULLIF(TRIM(p_numero_operacion), ''),
        NULLIF(TRIM(p_referencia), ''),
        NULLIF(TRIM(p_observacion), ''),
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

    RETURN json_build_object(
        'registro', json_build_object(
            'id', v_id_pago,
            'idCuenta', p_id_cuenta,
            'monto', v_monto,
            'saldoRestante', v_nuevo_saldo
        )
    );
END;
$$;


-- ===== database_sql/funciones/finanzas/fin_anular_pago.sql =====
-- Anula un pago (baja lógica) y revierte el saldo de la cuenta asociada.

DROP FUNCTION IF EXISTS fin_anular_pago(INT, VARCHAR, INT);

CREATE OR REPLACE FUNCTION fin_anular_pago(
    p_id_pago    INT,
    p_tipo       VARCHAR DEFAULT NULL,
    p_id_usuario INT     DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_tipo INT;
    v_pago    fin_pago%ROWTYPE;
    v_cuenta  fin_cuenta%ROWTYPE;
    v_err_caja TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_pago FROM fin_pago WHERE id = p_id_pago AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', false, 'id', p_id_pago, 'error', 'El pago no existe o ya fue anulado');
    END IF;

    v_err_caja := fin_caja_assert_abierta(v_pago.fecha_pago, NULL);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('eliminado', false, 'id', p_id_pago, 'error', v_err_caja);
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

    RETURN json_build_object('eliminado', true, 'id', p_id_pago);
END;
$$;


-- ===== database_sql/funciones/garantias/ven_eliminar_garantia.sql =====
DROP FUNCTION IF EXISTS ven_eliminar_garantia(INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION ven_eliminar_garantia(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_garantia RECORD;
    v_es_manual BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_garantia
    FROM ven_garantia
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'La garantía no existe o ya está inactiva'
        );
    END IF;

    v_es_manual :=
        v_garantia.id_prestamo IS NULL
        AND v_garantia.id_alquiler IS NULL
        AND NOT EXISTS (
            SELECT 1
            FROM ven_garantia_movimiento gm
            WHERE gm.id_garantia = v_garantia.id
              AND gm.estado = 1
              AND gm.id_comprobante IS NOT NULL
        );

    IF NOT v_es_manual THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'Solo se pueden eliminar garantías manuales'
        );
    END IF;

    IF COALESCE(v_garantia.monto_devuelto, 0) > 0 THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'No se puede eliminar una garantía con devoluciones. Anule primero los reembolsos.'
        );
    END IF;

    UPDATE ven_garantia_movimiento
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_garantia = p_id AND estado = 1;

    UPDATE ven_garantia
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('eliminado', true, 'id', p_id);
END;
$function$;


-- ===== database_sql/funciones/movimientos/pro_crear_movimiento.sql =====
DROP FUNCTION IF EXISTS pro_crear_movimiento(
    DATE, INTEGER, INTEGER, INTEGER, NUMERIC, INTEGER, INTEGER, VARCHAR, INTEGER
);
DROP FUNCTION IF EXISTS pro_crear_movimiento(
    DATE, INTEGER, INTEGER, INTEGER, NUMERIC, INTEGER, INTEGER, VARCHAR, INTEGER, BOOLEAN
);
DROP FUNCTION IF EXISTS pro_crear_movimiento(
    DATE, INTEGER, INTEGER, INTEGER, NUMERIC, INTEGER, INTEGER, VARCHAR, INTEGER, BOOLEAN, INTEGER
);

CREATE OR REPLACE FUNCTION pro_crear_movimiento(
    p_fecha DATE,
    p_id_producto INTEGER,
    p_id_almacen INTEGER,
    p_id_tipo_movimiento INTEGER,
    p_cantidad NUMERIC,
    p_id_documento_ref INTEGER DEFAULT NULL,
    p_id_tipo_documento_ref INTEGER DEFAULT NULL,
    p_glosa VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_forzar_ajuste_stock BOOLEAN DEFAULT FALSE,
    p_id_almacen_destino INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_stock INTEGER;
    v_id_stock_dest INTEGER;
    v_stock_anterior NUMERIC(12,4);
    v_stock_nuevo NUMERIC(12,4);
    v_stock_dest_ant NUMERIC(12,4);
    v_cantidad NUMERIC(12,4);
    v_afecta_stock BOOLEAN;
    v_nombre_tipo_movimiento VARCHAR;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del movimiento es obligatoria', 'registro', NULL);
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1) THEN
        RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_movimiento AND estado = 1) THEN
        RETURN json_build_object('error', 'El tipo de movimiento indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT
        COALESCE(p.afecta_stock, FALSE),
        REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
        COALESCE(p.es_gas, FALSE)
    INTO v_afecta_stock, v_nombre_unidad, v_es_gas
    FROM pro_producto p
    LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
    WHERE p.id = p_id_producto;

    IF COALESCE(p_forzar_ajuste_stock, FALSE) THEN
        v_afecta_stock := TRUE;
    END IF;

    IF NOT COALESCE(v_es_gas, FALSE)
       AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
       AND p_cantidad <> TRUNC(p_cantidad)
    THEN
        RETURN json_build_object(
            'error', 'La cantidad debe ser entera (unidad de medida UNID)',
            'registro', NULL
        );
    END IF;

    SELECT nombre INTO v_nombre_tipo_movimiento
    FROM gen_lista_opciones
    WHERE id = p_id_tipo_movimiento;

    v_cantidad := ABS(p_cantidad);
    v_es_traslado := UPPER(COALESCE(v_nombre_tipo_movimiento, '')) = 'TRASLADO';
    v_es_salida := v_nombre_tipo_movimiento ILIKE '%SALIDA%';

    IF v_es_traslado THEN
        IF p_id_almacen_destino IS NULL THEN
            RETURN json_build_object('error', 'El traslado requiere almacén de destino', 'registro', NULL);
        END IF;
        IF p_id_almacen_destino = p_id_almacen THEN
            RETURN json_build_object('error', 'El almacén de destino debe ser distinto al de origen', 'registro', NULL);
        END IF;
        IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1) THEN
            RETURN json_build_object('error', 'El almacén de destino no existe o está inactivo', 'registro', NULL);
        END IF;
        v_es_salida := TRUE;
    END IF;

    v_stock_anterior := 0;
    v_stock_nuevo := 0;

    IF v_afecta_stock THEN
        SELECT id, stock INTO v_id_stock, v_stock_anterior
        FROM pro_stock
        WHERE id_almacen = p_id_almacen
          AND id_producto = p_id_producto
          AND estado = 1
        FOR UPDATE;

        IF v_id_stock IS NULL THEN
            INSERT INTO pro_stock (
                id_almacen, id_producto, stock, stock_minimo,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                p_id_almacen, p_id_producto, 0, 0,
                p_id_usuario_auditoria, p_id_usuario_auditoria
            )
            RETURNING id, stock INTO v_id_stock, v_stock_anterior;
        END IF;

        IF v_es_salida THEN
            v_stock_nuevo := v_stock_anterior - v_cantidad;
        ELSE
            v_stock_nuevo := v_stock_anterior + v_cantidad;
        END IF;

        IF v_stock_nuevo < 0 THEN
            RETURN json_build_object('error', 'Stock insuficiente para registrar la salida', 'registro', NULL);
        END IF;

        UPDATE pro_stock
        SET stock = v_stock_nuevo,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_stock;

        IF v_es_traslado THEN
            SELECT id, stock INTO v_id_stock_dest, v_stock_dest_ant
            FROM pro_stock
            WHERE id_almacen = p_id_almacen_destino
              AND id_producto = p_id_producto
              AND estado = 1
            FOR UPDATE;

            IF v_id_stock_dest IS NULL THEN
                INSERT INTO pro_stock (
                    id_almacen, id_producto, stock, stock_minimo,
                    id_usuario_creacion, id_usuario_modificacion
                )
                VALUES (
                    p_id_almacen_destino, p_id_producto, 0, 0,
                    p_id_usuario_auditoria, p_id_usuario_auditoria
                )
                RETURNING id, stock INTO v_id_stock_dest, v_stock_dest_ant;
            END IF;

            UPDATE pro_stock
            SET stock = COALESCE(v_stock_dest_ant, 0) + v_cantidad,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_stock_dest;
        END IF;
    END IF;

    INSERT INTO pro_movimientos (
        fecha, id_producto, id_almacen, id_tipo_movimiento, cantidad,
        stock_anterior, stock_nuevo, id_documento_ref, id_tipo_documento_ref,
        glosa, id_almacen_destino,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_fecha, p_id_producto, p_id_almacen, p_id_tipo_movimiento, v_cantidad,
        CASE WHEN v_afecta_stock THEN v_stock_anterior ELSE NULL END,
        CASE WHEN v_afecta_stock THEN v_stock_nuevo ELSE NULL END,
        p_id_documento_ref, p_id_tipo_documento_ref, p_glosa, p_id_almacen_destino,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_movimiento(v_id);
END;
$function$;


-- ===== database_sql/funciones/movimientos/pro_eliminar_movimiento.sql =====
CREATE OR REPLACE FUNCTION pro_eliminar_movimiento(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_movimiento pro_movimientos%ROWTYPE;
    v_id_stock INTEGER;
    v_id_stock_dest INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_afecta_stock BOOLEAN;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_nombre_tipo_movimiento VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_movimiento
    FROM pro_movimientos
    WHERE id = p_id AND estado = 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_movimiento.id_documento_ref IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede anular un movimiento vinculado a una venta/comprobante'
        );
    END IF;

    SELECT afecta_stock INTO v_afecta_stock
    FROM pro_producto
    WHERE id = v_movimiento.id_producto;

    IF v_afecta_stock
       AND v_movimiento.stock_anterior IS NOT NULL
       AND v_movimiento.stock_nuevo IS NOT NULL THEN
        SELECT nombre INTO v_nombre_tipo_movimiento
        FROM gen_lista_opciones
        WHERE id = v_movimiento.id_tipo_movimiento;

        v_es_salida := v_nombre_tipo_movimiento ILIKE '%SALIDA%';
        v_es_traslado := UPPER(COALESCE(v_nombre_tipo_movimiento, '')) = 'TRASLADO';
        IF v_es_traslado THEN
            v_es_salida := TRUE;
        END IF;

        SELECT id, stock INTO v_id_stock, v_stock_actual
        FROM pro_stock
        WHERE id_almacen = v_movimiento.id_almacen
          AND id_producto = v_movimiento.id_producto
          AND estado = 1
        FOR UPDATE;

        IF v_id_stock IS NULL THEN
            RETURN json_build_object(
                'eliminado', FALSE,
                'id', p_id,
                'error', 'No se encontró el registro de stock para revertir el movimiento'
            );
        END IF;

        IF v_es_salida THEN
            v_stock_revertido := v_stock_actual + v_movimiento.cantidad;
        ELSE
            v_stock_revertido := v_stock_actual - v_movimiento.cantidad;
        END IF;

        IF v_stock_revertido < 0 THEN
            RETURN json_build_object(
                'eliminado', FALSE,
                'id', p_id,
                'error', 'No se puede anular el movimiento porque revertiría un stock negativo'
            );
        END IF;

        UPDATE pro_stock
        SET stock = v_stock_revertido,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_stock;

        IF v_es_traslado AND v_movimiento.id_almacen_destino IS NOT NULL THEN
            SELECT id, stock INTO v_id_stock_dest, v_stock_actual
            FROM pro_stock
            WHERE id_almacen = v_movimiento.id_almacen_destino
              AND id_producto = v_movimiento.id_producto
              AND estado = 1
            FOR UPDATE;

            IF v_id_stock_dest IS NULL THEN
                RETURN json_build_object(
                    'eliminado', FALSE,
                    'id', p_id,
                    'error', 'No se encontró el stock de destino para revertir el traslado'
                );
            END IF;

            v_stock_revertido := v_stock_actual - v_movimiento.cantidad;
            IF v_stock_revertido < 0 THEN
                RETURN json_build_object(
                    'eliminado', FALSE,
                    'id', p_id,
                    'error', 'No se puede anular el traslado porque el destino ya no tiene esa cantidad'
                );
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_revertido,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_stock_dest;
        END IF;
    END IF;

    UPDATE pro_movimientos
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ===== database_sql/funciones/movimientos/pro_obtener_movimiento.sql =====
CREATE OR REPLACE FUNCTION pro_obtener_movimiento(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            m.id,
            m.fecha,
            m.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            COALESCE(p.es_gas, FALSE) AS es_gas,
            umed.nombre AS nombre_unidad_medida,
            m.id_almacen,
            a.nombre AS nombre_almacen,
            m.id_almacen_destino,
            ad.nombre AS nombre_almacen_destino,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.cantidad,
            m.stock_anterior,
            m.stock_nuevo,
            m.id_documento_ref,
            m.id_tipo_documento_ref,
            tdr.nombre AS nombre_tipo_documento_ref,
            m.glosa,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            m.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM pro_movimientos m
        INNER JOIN pro_producto p ON m.id_producto = p.id
        INNER JOIN gen_almacen a ON m.id_almacen = a.id
        LEFT JOIN gen_almacen ad ON m.id_almacen_destino = ad.id
        LEFT JOIN gen_lista_opciones umed ON umed.id = p.id_unidad_medida
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tdr ON m.id_tipo_documento_ref = tdr.id
        LEFT JOIN auth_usuarios uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON m.id_usuario_modificacion = um.id
        WHERE m.id = p_id AND m.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;


-- ===== database_sql/funciones/movimientos/pro_listar_movimientos.sql =====
CREATE OR REPLACE FUNCTION pro_listar_movimientos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_producto INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_tipo_movimiento INTEGER DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COUNT(*),
        json_build_object(
            'total', COUNT(*),
            'ingresos', COUNT(*) FILTER (WHERE tm.nombre ILIKE '%INGRESO%'),
            'salidas', COUNT(*) FILTER (WHERE tm.nombre ILIKE '%SALIDA%'),
            'ajustes', COUNT(*) FILTER (WHERE tm.nombre ILIKE '%AJUSTE%')
        )
    INTO v_total, v_resumen
    FROM pro_movimientos m
    INNER JOIN pro_producto p ON m.id_producto = p.id
    INNER JOIN gen_almacen a ON m.id_almacen = a.id
    LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
    WHERE m.estado = 1
      AND (p_id_producto IS NULL OR m.id_producto = p_id_producto)
      AND (p_id_almacen IS NULL OR m.id_almacen = p_id_almacen)
      AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
      AND (p_fecha_desde IS NULL OR m.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR m.fecha <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(COALESCE(m.glosa, ''), p_busqueda)
          OR gen_texto_coincide(p.codigo, p_busqueda)
          OR gen_texto_coincide(p.nombre, p_busqueda)
          OR gen_texto_coincide(a.nombre, p_busqueda)
          OR gen_texto_coincide(COALESCE(tm.nombre, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            m.id,
            m.fecha,
            m.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            p.afecta_stock,
            COALESCE(p.es_gas, FALSE) AS es_gas,
            umed.nombre AS nombre_unidad_medida,
            m.id_almacen,
            a.nombre AS nombre_almacen,
            m.id_almacen_destino,
            adest.nombre AS nombre_almacen_destino,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.cantidad,
            m.stock_anterior,
            m.stock_nuevo,
            m.id_documento_ref,
            m.id_tipo_documento_ref,
            tdr.nombre AS nombre_tipo_documento_ref,
            m.glosa,
            m.estado,
            CASE
                WHEN m.id_documento_ref IS NOT NULL THEN FALSE
                WHEN NOT COALESCE(p.afecta_stock, FALSE)
                  OR m.stock_anterior IS NULL
                  OR m.stock_nuevo IS NULL
                THEN TRUE
                WHEN st.id IS NULL THEN FALSE
                WHEN tm.nombre ILIKE '%SALIDA%' THEN TRUE
                WHEN COALESCE(st.stock, 0) - m.cantidad < 0 THEN FALSE
                ELSE TRUE
            END AS puede_anular,
            CASE
                WHEN m.id_documento_ref IS NOT NULL THEN 'Vinculado a una venta'
                WHEN NOT COALESCE(p.afecta_stock, FALSE)
                  OR m.stock_anterior IS NULL
                  OR m.stock_nuevo IS NULL
                THEN NULL
                WHEN st.id IS NULL THEN 'Sin registro de stock para revertir'
                WHEN tm.nombre ILIKE '%SALIDA%' THEN NULL
                WHEN COALESCE(st.stock, 0) - m.cantidad < 0 THEN 'Revertiría stock negativo'
                ELSE NULL
            END AS motivo_bloqueo_anulacion,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            m.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM pro_movimientos m
        INNER JOIN pro_producto p ON m.id_producto = p.id
        INNER JOIN gen_almacen a ON m.id_almacen = a.id
        LEFT JOIN gen_almacen adest ON m.id_almacen_destino = adest.id
        LEFT JOIN gen_lista_opciones umed ON umed.id = p.id_unidad_medida
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tdr ON m.id_tipo_documento_ref = tdr.id
        LEFT JOIN auth_usuarios uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON m.id_usuario_modificacion = um.id
        LEFT JOIN pro_stock st
            ON st.id_almacen = m.id_almacen
           AND st.id_producto = m.id_producto
           AND st.estado = 1
        WHERE m.estado = 1
          AND (p_id_producto IS NULL OR m.id_producto = p_id_producto)
          AND (p_id_almacen IS NULL OR m.id_almacen = p_id_almacen)
          AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
          AND (p_fecha_desde IS NULL OR m.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR m.fecha <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(m.glosa, ''), p_busqueda)
              OR gen_texto_coincide(p.codigo, p_busqueda)
              OR gen_texto_coincide(p.nombre, p_busqueda)
              OR gen_texto_coincide(a.nombre, p_busqueda)
              OR gen_texto_coincide(COALESCE(tm.nombre, ''), p_busqueda)
          )
        ORDER BY m.fecha DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', v_resumen
    );
END;
$function$;
