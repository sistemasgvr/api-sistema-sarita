-- Indica si los cobros de una venta (líneas o, sin líneas, el medio de cabecera) mueven efectivo de la caja
DROP FUNCTION IF EXISTS public.ven_pagos_mueven_efectivo (
  p_pagos json,
  p_id_medio_pago integer,
  p_id_condicion_pago integer
);

CREATE OR REPLACE FUNCTION public.ven_pagos_mueven_efectivo (
  p_pagos json DEFAULT NULL::json,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_id_condicion_pago integer DEFAULT NULL::integer
) RETURNS boolean LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_es_credito BOOLEAN := FALSE;
BEGIN
    IF p_pagos IS NOT NULL
       AND json_typeof(p_pagos) = 'array'
       AND json_array_length(p_pagos) > 0 THEN
        -- Una línea sin medio se trata como efectivo (criterio conservador: exige la caja).
        RETURN EXISTS (
            SELECT 1
            FROM json_array_elements(p_pagos) j
            WHERE NULLIF(j.value ->> 'idMedioPago', '') IS NULL
               OR fin_medio_pago_flag((j.value ->> 'idMedioPago')::INTEGER, 'ES_EFECTIVO')
        );
    END IF;

    -- Sin líneas de cobro la venta se cobra con la cabecera (mismo criterio que ven_pagos_de_comprobante).
    SELECT COALESCE(cp.dias_credito, 0) > 0 OR COALESCE(cp.numero_cuotas, 0) > 1
    INTO v_es_credito
    FROM gen_condicion_pago cp
    WHERE cp.id = p_id_condicion_pago;

    IF COALESCE(v_es_credito, FALSE) THEN
        RETURN FALSE;
    END IF;

    -- Sin medio, la caja lo cuenta como efectivo (fin_caja_calcular_totales).
    IF p_id_medio_pago IS NULL THEN
        RETURN TRUE;
    END IF;

    RETURN fin_medio_pago_flag(p_id_medio_pago, 'ES_EFECTIVO');
END;
$function$;
