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
END;
$function$;
