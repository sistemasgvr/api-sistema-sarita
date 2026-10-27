-- Completa los datos de cobro (operación, cuenta) de una venta ya emitida
DROP FUNCTION IF EXISTS public.ven_registrar_cobro_comprobante (
  p_id_comprobante integer,
  p_pagos json,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.ven_registrar_cobro_comprobante (
  p_id_comprobante integer,
  p_pagos json DEFAULT NULL::json,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado VARCHAR;
    v_pago JSON;
    v_id_pago INTEGER;
    v_id_cuenta INTEGER;
    v_linea RECORD;
    v_error TEXT;
    v_actualizados INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_pagos IS NULL OR json_typeof(p_pagos) <> 'array' THEN
        RETURN json_build_object('error', 'Los cobros deben enviarse como una lista', 'registro', NULL);
    END IF;

    SELECT UPPER(COALESCE(est.nombre, ''))
    INTO v_estado
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
    WHERE c.id = p_id_comprobante AND c.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El comprobante no existe o está inactivo', 'registro', NULL);
    END IF;

    IF v_estado = 'ANULADO' THEN
        RETURN json_build_object(
            'error', 'El comprobante está anulado: no se puede registrar su cobro',
            'registro', NULL
        );
    END IF;

    FOR v_pago IN SELECT * FROM json_array_elements(p_pagos)
    LOOP
        v_id_pago := NULLIF(v_pago ->> 'idPago', '')::INTEGER;

        IF v_id_pago IS NULL THEN
            RETURN json_build_object(
                'error', 'Falta el identificador de la línea de cobro', 'registro', NULL
            );
        END IF;

        SELECT * INTO v_linea
        FROM ven_comprobante_pago
        WHERE id = v_id_pago AND id_comprobante = p_id_comprobante AND estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object(
                'error', format('La línea de cobro %s no pertenece a este comprobante', v_id_pago),
                'registro', NULL
            );
        END IF;

        v_id_cuenta := COALESCE(
            NULLIF(v_pago ->> 'idCuentaBancaria', '')::INTEGER,
            v_linea.id_cuenta_bancaria
        );

        v_error := fin_validar_cuenta_medio_pago(v_linea.id_medio_pago, v_id_cuenta);
        IF v_error IS NOT NULL THEN
            RETURN json_build_object('error', v_error, 'registro', NULL);
        END IF;

        UPDATE ven_comprobante_pago
        SET numero_operacion = COALESCE(
                NULLIF(TRIM(COALESCE(v_pago ->> 'numeroOperacion', '')), ''),
                numero_operacion
            ),
            referencia = COALESCE(
                NULLIF(TRIM(COALESCE(v_pago ->> 'referencia', '')), ''),
                referencia
            ),
            observacion = COALESCE(
                NULLIF(TRIM(COALESCE(v_pago ->> 'observacion', '')), ''),
                observacion
            ),
            id_cuenta_bancaria = v_id_cuenta,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_id_pago;

        v_actualizados := v_actualizados + 1;
    END LOOP;

    RETURN json_build_object(
        'registro', json_build_object(
            'idComprobante', p_id_comprobante,
            'actualizados', v_actualizados,
            'pagos', (ven_obtener_comprobante(p_id_comprobante)) -> 'pagos'
        )
    );
END;
$function$;
