-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_total_clientes
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.957Z
DROP FUNCTION IF EXISTS dash_total_clientes(p_id_cliente integer, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION dash_total_clientes(p_id_cliente integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*)::INTEGER
    INTO v_total
    FROM cli_clientes
    WHERE estado = 1
      AND (p_id_cliente IS NULL OR id = p_id_cliente)
      AND (p_fecha_desde IS NULL OR fecha_creacion::date >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR fecha_creacion::date <= p_fecha_hasta);

    RETURN v_total;
END;
$function$;
