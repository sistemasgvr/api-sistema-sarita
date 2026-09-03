-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_creditos_otorgados
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.955Z
DROP FUNCTION IF EXISTS dash_creditos_otorgados(p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION dash_creditos_otorgados(p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_cobrar INT;
    v_total          NUMERIC(14,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT glo.id INTO v_id_tipo_cobrar
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = 'COBRAR'
    LIMIT 1;

    SELECT COALESCE(SUM(fc.monto_pendiente), 0)
    INTO v_total
    FROM fin_cuenta fc
    WHERE fc.estado = 1
      AND fc.id_tipo_cuenta = v_id_tipo_cobrar
      AND fc.numero_cuotas_total IS NULL
      AND (p_fecha_desde IS NULL OR fc.fecha_emision >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR fc.fecha_emision <= p_fecha_hasta);

    RETURN v_total;
END;
$function$;
