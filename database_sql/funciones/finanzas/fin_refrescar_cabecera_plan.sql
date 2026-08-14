-- Recalcula abonado/saldo de la cabecera a partir de las cuotas hijas.
-- Si ninguna hija tiene saldo a céntimos, la cabecera queda PAGADA
-- (absorbe el céntimo de redondeo 1000 vs 333.33×3).
CREATE OR REPLACE FUNCTION fin_refrescar_cabecera_plan(p_id_padre INTEGER)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_pendiente        NUMERIC(12,2);
    v_total_abonado    NUMERIC(12,2);
    v_total_saldo      NUMERIC(12,2);
    v_hijas_pendientes INTEGER;
BEGIN
    IF p_id_padre IS NULL THEN
        RETURN;
    END IF;

    SELECT fin_redondear_monto(monto_pendiente)
    INTO v_pendiente
    FROM fin_cuenta
    WHERE id = p_id_padre AND estado = 1;

    IF v_pendiente IS NULL THEN
        RETURN;
    END IF;

    SELECT
        fin_redondear_monto(COALESCE(SUM(COALESCE(monto_abonado, 0)), 0)),
        fin_redondear_monto(COALESCE(SUM(COALESCE(
            monto_saldo,
            monto_pendiente - COALESCE(monto_abonado, 0)
        )), 0)),
        COUNT(*) FILTER (
            WHERE fin_redondear_monto(COALESCE(
                monto_saldo,
                monto_pendiente - COALESCE(monto_abonado, 0)
            )) > 0
        )
    INTO v_total_abonado, v_total_saldo, v_hijas_pendientes
    FROM fin_cuenta
    WHERE id_cuenta_padre = p_id_padre AND estado = 1;

    IF COALESCE(v_hijas_pendientes, 0) = 0 THEN
        v_total_abonado := v_pendiente;
        v_total_saldo := 0;
    END IF;

    UPDATE fin_cuenta
    SET
        monto_abonado = v_total_abonado,
        monto_saldo = v_total_saldo,
        fecha_modificacion = NOW()
    WHERE id = p_id_padre;
END;
$$;
