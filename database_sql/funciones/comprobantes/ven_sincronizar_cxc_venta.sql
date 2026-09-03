-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_sincronizar_cxc_venta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_sincronizar_cxc_venta(p_id_comprobante integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION ven_sincronizar_cxc_venta(p_id_comprobante integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS void
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
