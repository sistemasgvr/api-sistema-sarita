-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_sincronizar_cxp_compra
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.641Z
DROP FUNCTION IF EXISTS com_sincronizar_cxp_compra(p_id_comprobante integer, p_id_usuario_auditoria integer, p_fecha_vencimiento date, p_cuotas jsonb);

CREATE OR REPLACE FUNCTION com_sincronizar_cxp_compra(p_id_comprobante integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_fecha_vencimiento date DEFAULT NULL::date, p_cuotas jsonb DEFAULT NULL::jsonb)
 RETURNS void
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
$function$
