-- Redondeo a céntimos (2 decimales) para montos de finanzas.
CREATE OR REPLACE FUNCTION fin_redondear_monto(p_monto NUMERIC)
RETURNS NUMERIC(12,2)
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT ROUND(COALESCE(p_monto, 0), 2)::NUMERIC(12,2);
$$;
