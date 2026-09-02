-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_capacidad_disponible_balon
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.524Z
DROP FUNCTION IF EXISTS bal_capacidad_disponible_balon(p_id_balon integer);

CREATE OR REPLACE FUNCTION bal_capacidad_disponible_balon(p_id_balon integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_disponible NUMERIC;
BEGIN
    SELECT COALESCE(tb.capacidad, 0)
    INTO v_disponible
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon
      AND b.estado = 1;

    RETURN COALESCE(v_disponible, 0);
END;
$function$
