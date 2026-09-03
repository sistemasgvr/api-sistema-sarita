-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_factor_lb_m3
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.946Z
DROP FUNCTION IF EXISTS bal_factor_lb_m3(p_id_tipo_balon integer, p_id_producto_gas integer);

CREATE OR REPLACE FUNCTION bal_factor_lb_m3(p_id_tipo_balon integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_cap_m3 NUMERIC;
    v_cap_lb NUMERIC;
    v_factor_prod NUMERIC;
BEGIN
    IF p_id_tipo_balon IS NOT NULL THEN
        SELECT tb.capacidad, tb.capacidad_lb
        INTO v_cap_m3, v_cap_lb
        FROM bal_tipo_balon tb
        WHERE tb.id = p_id_tipo_balon AND tb.estado = 1;

        IF v_cap_m3 IS NOT NULL AND v_cap_m3 > 0 AND v_cap_lb IS NOT NULL AND v_cap_lb > 0 THEN
            RETURN ROUND(v_cap_m3 / v_cap_lb, 6);
        END IF;
    END IF;

    IF p_id_producto_gas IS NOT NULL THEN
        SELECT p.factor_lb_m3
        INTO v_factor_prod
        FROM pro_producto p
        WHERE p.id = p_id_producto_gas AND p.estado = 1;

        IF v_factor_prod IS NOT NULL AND v_factor_prod > 0 THEN
            RETURN ROUND(v_factor_prod, 6);
        END IF;
    END IF;

    RETURN 0.317400;
END;
$function$;
