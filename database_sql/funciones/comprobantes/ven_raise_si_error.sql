-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_raise_si_error
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_raise_si_error(p_result json);

CREATE OR REPLACE FUNCTION ven_raise_si_error(p_result json)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_result IS NULL THEN
        RAISE EXCEPTION 'La operación POS no devolvió resultado';
    END IF;

    IF p_result->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', p_result->>'error';
    END IF;
END;
$function$;
