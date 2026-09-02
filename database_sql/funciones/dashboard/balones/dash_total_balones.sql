-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_total_balones
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.659Z
DROP FUNCTION IF EXISTS dash_total_balones(p_id_cliente integer);

CREATE OR REPLACE FUNCTION dash_total_balones(p_id_cliente integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_total INTEGER;
BEGIN
  SET TIME ZONE 'America/Lima';

  SELECT COUNT(*)::INTEGER
  INTO v_total
  FROM bal_balon
  WHERE estado = 1
    AND (p_id_cliente IS NULL OR id_cliente_ubicacion = p_id_cliente);

  RETURN v_total;
END;
$function$
