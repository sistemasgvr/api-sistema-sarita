-- Reemplaza las líneas de cobro de un comprobante validando el total
DROP FUNCTION IF EXISTS public.ven_sincronizar_pagos_comprobante (
  p_id_comprobante integer,
  p_pagos json,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.ven_sincronizar_pagos_comprobante (
  p_id_comprobante integer,
  p_pagos json DEFAULT NULL::json,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS text LANGUAGE plpgsql AS $function$
DECLARE
    v_total_comprobante NUMERIC(12,4);
    v_total_pagos NUMERIC(12,4);
    v_error TEXT;
    v_item INT := 0;
    v_pago JSON;
    v_id_medio INT;
    v_id_cuenta INT;
    v_monto NUMERIC(12,4);
    v_medio_principal INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_pagos IS NULL THEN
        RETURN NULL;
    END IF;

    IF json_typeof(p_pagos) <> 'array' THEN
        RETURN 'Los pagos deben enviarse como una lista.';
    END IF;

    SELECT total_importe INTO v_total_comprobante
    FROM ven_comprobante
    WHERE id = p_id_comprobante AND estado = 1;

    IF NOT FOUND THEN
        RETURN format('El comprobante (id %s) no existe o está inactivo.', p_id_comprobante);
    END IF;

    v_total_pagos := 0;

    FOR v_pago IN SELECT * FROM json_array_elements(p_pagos)
    LOOP
        v_item := v_item + 1;
        v_id_medio  := NULLIF(v_pago ->> 'idMedioPago', '')::INTEGER;
        v_id_cuenta := NULLIF(v_pago ->> 'idCuentaBancaria', '')::INTEGER;
        v_monto := CASE
            WHEN NULLIF(v_pago ->> 'monto', '') IS NULL AND json_array_length(p_pagos) = 1
                THEN ROUND(COALESCE(v_total_comprobante, 0), 4)
            ELSE ROUND(COALESCE(NULLIF(v_pago ->> 'monto', ''), '0')::NUMERIC, 4)
        END;

        IF v_id_medio IS NULL THEN
            RETURN format('El pago %s no indica medio de pago.', v_item);
        END IF;

        IF v_monto <= 0 THEN
            RETURN format('El monto del pago %s debe ser mayor que cero.', v_item);
        END IF;

        v_error := fin_validar_cuenta_medio_pago(v_id_medio, v_id_cuenta);
        IF v_error IS NOT NULL THEN
            RETURN format('Pago %s: %s', v_item, v_error);
        END IF;

        v_total_pagos := v_total_pagos + v_monto;
    END LOOP;

    IF json_array_length(p_pagos) > 0
       AND ABS(v_total_pagos - COALESCE(v_total_comprobante, 0)) > 0.01 THEN
        RETURN format(
            'Los pagos suman %s y el comprobante es de %s. Deben coincidir.',
            gen_formato_cantidad(v_total_pagos),
            gen_formato_cantidad(COALESCE(v_total_comprobante, 0))
        );
    END IF;

    DELETE FROM ven_comprobante_pago WHERE id_comprobante = p_id_comprobante;

    IF json_array_length(p_pagos) = 0 THEN
        RETURN NULL;
    END IF;

    v_item := 0;
    FOR v_pago IN SELECT * FROM json_array_elements(p_pagos)
    LOOP
        v_item := v_item + 1;
        INSERT INTO ven_comprobante_pago (
            id_comprobante, item, id_medio_pago, id_cuenta_bancaria, monto,
            numero_operacion, referencia, observacion,
            id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            p_id_comprobante,
            v_item,
            (v_pago ->> 'idMedioPago')::INTEGER,
            NULLIF(v_pago ->> 'idCuentaBancaria', '')::INTEGER,
            CASE
                WHEN NULLIF(v_pago ->> 'monto', '') IS NULL AND json_array_length(p_pagos) = 1
                    THEN ROUND(COALESCE(v_total_comprobante, 0), 4)
                ELSE ROUND((v_pago ->> 'monto')::NUMERIC, 4)
            END,
            NULLIF(TRIM(COALESCE(v_pago ->> 'numeroOperacion', '')), ''),
            NULLIF(TRIM(COALESCE(v_pago ->> 'referencia', '')), ''),
            NULLIF(TRIM(COALESCE(v_pago ->> 'observacion', '')), ''),
            p_id_usuario, p_id_usuario
        );
    END LOOP;

    SELECT id_medio_pago INTO v_medio_principal
    FROM ven_comprobante_pago
    WHERE id_comprobante = p_id_comprobante AND estado = 1
    ORDER BY monto DESC, item ASC
    LIMIT 1;

    UPDATE ven_comprobante
    SET id_medio_pago = COALESCE(v_medio_principal, id_medio_pago),
        id_usuario_modificacion = COALESCE(p_id_usuario, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    RETURN NULL;
END;
$function$;
