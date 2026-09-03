-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_recalcular_totales_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
DROP FUNCTION IF EXISTS com_recalcular_totales_compra(p_id_comprobante integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_recalcular_totales_compra(p_id_comprobante integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS void
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
