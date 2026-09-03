-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_psi_minimo_util
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.949Z
DROP FUNCTION IF EXISTS bal_psi_minimo_util();

CREATE OR REPLACE FUNCTION bal_psi_minimo_util()
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_psi NUMERIC;
BEGIN
    SELECT e.psi_minimo_util
    INTO v_psi
    FROM gen_empresa e
    WHERE e.estado = 1
    ORDER BY e.id
    LIMIT 1;

    RETURN COALESCE(v_psi, 100);
END;
$function$;
