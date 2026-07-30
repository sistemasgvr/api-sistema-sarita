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
END;
$function$;
