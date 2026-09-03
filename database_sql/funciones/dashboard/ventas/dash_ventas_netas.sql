-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_ventas_netas
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.957Z
DROP FUNCTION IF EXISTS dash_ventas_netas(p_fecha_desde date, p_fecha_hasta date, p_id_cliente integer);

CREATE OR REPLACE FUNCTION dash_ventas_netas(p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_id_cliente integer DEFAULT NULL::integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total NUMERIC(14,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(SUM(total_importe), 0)
    INTO v_total
    FROM ven_comprobante
    WHERE estado = 1
      AND id_tipo_comprobante IN (102, 104, 192)
      AND (p_fecha_desde IS NULL OR fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR fecha <= p_fecha_hasta)
      AND (p_id_cliente IS NULL OR id_cliente = p_id_cliente);

    RETURN v_total;
END;
$function$;
