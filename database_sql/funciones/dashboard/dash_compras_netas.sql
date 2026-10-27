-- Dashboard: suma del importe de compras activas en un rango de fechas
DROP FUNCTION IF EXISTS public.dash_compras_netas (p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION public.dash_compras_netas (
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date
) RETURNS numeric LANGUAGE plpgsql AS $function$
DECLARE
    v_total NUMERIC(14,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(SUM(total_importe), 0)
    INTO v_total
    FROM com_comprobante_compra
    WHERE estado = 1
      AND (p_fecha_desde IS NULL OR fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR fecha <= p_fecha_hasta);

    RETURN v_total;
END;
$function$;
