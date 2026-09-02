-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_m3_desde_psi
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.580Z
DROP FUNCTION IF EXISTS bal_m3_desde_psi(p_id_tipo_balon integer, p_psi numeric);

CREATE OR REPLACE FUNCTION bal_m3_desde_psi(p_id_tipo_balon integer, p_psi numeric)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_cap NUMERIC;
    v_psi_lleno NUMERIC;
BEGIN
    IF p_id_tipo_balon IS NULL OR p_psi IS NULL OR p_psi < 0 THEN
        RETURN NULL;
    END IF;

    SELECT tb.capacidad, tb.presion_llenado_psi
    INTO v_cap, v_psi_lleno
    FROM bal_tipo_balon tb
    WHERE tb.id = p_id_tipo_balon AND tb.estado = 1;

    IF v_cap IS NULL OR v_cap <= 0 OR v_psi_lleno IS NULL OR v_psi_lleno <= 0 THEN
        RETURN NULL;
    END IF;

    RETURN ROUND(v_cap * LEAST(p_psi / v_psi_lleno, 1), 4);
END;
$function$
