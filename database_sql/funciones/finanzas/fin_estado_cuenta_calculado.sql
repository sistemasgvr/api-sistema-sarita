-- Estado visible de una cuenta o cuota. No se persiste: se calcula siempre.
-- PAGADO si el saldo a céntimos es 0 (evita PARCIAL por residuos 0.0033).
CREATE OR REPLACE FUNCTION fin_estado_cuenta_calculado(
    p_saldo            NUMERIC,
    p_monto_abonado    NUMERIC,
    p_fecha_vencimiento DATE
)
RETURNS VARCHAR
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN fin_redondear_monto(p_saldo) <= 0 THEN 'PAGADO'
        WHEN p_fecha_vencimiento IS NOT NULL AND p_fecha_vencimiento < CURRENT_DATE THEN 'VENCIDO'
        WHEN fin_redondear_monto(p_monto_abonado) > 0 THEN 'PARCIAL'
        ELSE 'PENDIENTE'
    END;
$$;
