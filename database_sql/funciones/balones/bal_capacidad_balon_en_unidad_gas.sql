-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_capacidad_balon_en_unidad_gas
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.944Z
DROP FUNCTION IF EXISTS bal_capacidad_balon_en_unidad_gas(p_id_balon integer);

CREATE OR REPLACE FUNCTION bal_capacidad_balon_en_unidad_gas(p_id_balon integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_capacidad NUMERIC;
    v_id_unidad_tipo INTEGER;
    v_id_producto_gas INTEGER;
BEGIN
    IF p_id_balon IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT tb.capacidad, tb.id_unidad_medida, COALESCE(b.id_producto_gas, tb.id_gas)
    INTO v_capacidad, v_id_unidad_tipo, v_id_producto_gas
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND OR COALESCE(v_capacidad, 0) <= 0 OR v_id_producto_gas IS NULL THEN
        RETURN v_capacidad;
    END IF;

    RETURN inv_convertir_a_unidad_producto(v_id_producto_gas, v_capacidad, v_id_unidad_tipo);
END;
$function$;
