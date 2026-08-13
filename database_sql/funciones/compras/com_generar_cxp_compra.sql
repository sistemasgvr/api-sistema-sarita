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
