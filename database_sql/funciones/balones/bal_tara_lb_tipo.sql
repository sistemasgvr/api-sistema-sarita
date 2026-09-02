-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_tara_lb_tipo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.609Z
DROP FUNCTION IF EXISTS bal_tara_lb_tipo(p_id_tipo_balon integer);

CREATE OR REPLACE FUNCTION bal_tara_lb_tipo(p_id_tipo_balon integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_tara_lb NUMERIC;
    v_peso_kg NUMERIC;
BEGIN
    IF p_id_tipo_balon IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT tb.peso_tara_lb, tb.peso
    INTO v_tara_lb, v_peso_kg
    FROM bal_tipo_balon tb
    WHERE tb.id = p_id_tipo_balon AND tb.estado = 1;

    IF v_tara_lb IS NOT NULL AND v_tara_lb > 0 THEN
        RETURN ROUND(v_tara_lb, 4);
    END IF;

    IF v_peso_kg IS NOT NULL AND v_peso_kg > 0 THEN
        RETURN ROUND(v_peso_kg * 2.20462, 4);
    END IF;

    RETURN NULL;
END;
$function$
