-- Caja: una caja abierta admite movimientos con su fecha aunque sea de un día anterior.
-- Ventas: el cobro de una venta emitida permite cambiar el medio de pago.

-- Valida que la caja de una fecha y sucursal esté abierta; devuelve el error o NULL
DROP FUNCTION IF EXISTS public.fin_caja_assert_abierta (p_fecha date, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION public.fin_caja_assert_abierta (
  p_fecha date,
  p_id_sucursal integer DEFAULT NULL::integer
) RETURNS text LANGUAGE plpgsql AS $function$
DECLARE
    v_estado VARCHAR;
    v_pendiente_fecha DATE;
    v_hoy DATE;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_hoy := CURRENT_DATE;

    IF p_fecha IS NULL THEN
        RETURN 'La fecha es obligatoria para validar la caja';
    END IF;

    SELECT UPPER(est.nombre) INTO v_estado
    FROM fin_caja_sesion s
    INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    ORDER BY s.id DESC
    LIMIT 1;

    -- La caja abierta de la fecha del movimiento lo admite, aunque sea de un día anterior.
    IF v_estado = 'ABIERTA' THEN
        RETURN NULL;
    END IF;

    IF v_estado = 'CERRADA' THEN
        RETURN 'La caja de esta fecha ya está cerrada. No se pueden registrar más operaciones.';
    END IF;

    IF v_estado IS NOT NULL THEN
        RETURN 'La sesión de caja no está abierta.';
    END IF;

    SELECT s.fecha INTO v_pendiente_fecha
    FROM fin_caja_sesion s
    INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.estado = 1
      AND UPPER(est.nombre) = 'ABIERTA'
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
      AND s.fecha < v_hoy
    ORDER BY s.fecha ASC
    LIMIT 1;

    IF v_pendiente_fecha IS NOT NULL THEN
        RETURN format(
            'Hay una caja sin cerrar del %s. Registra con fecha %s para usar esa caja, o ciérrala en Ventas → Caja (arqueo) y abre la de hoy.',
            to_char(v_pendiente_fecha, 'DD/MM/YYYY'),
            to_char(v_pendiente_fecha, 'DD/MM/YYYY')
        );
    END IF;

    RETURN 'No hay caja abierta para esta fecha. Abre la caja en Ventas → Caja antes de continuar.';
END;
$function$;

-- Completa o corrige los datos de cobro (medio, cuenta, operación) de una venta ya emitida
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
    v_fecha DATE;
    v_id_sucursal INTEGER;
    v_pago JSON;
    v_id_pago INTEGER;
    v_id_medio INTEGER;
    v_id_cuenta INTEGER;
    v_cambia_medio BOOLEAN;
    v_linea RECORD;
    v_error TEXT;
    v_actualizados INTEGER := 0;
    v_medio_principal INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_pagos IS NULL OR json_typeof(p_pagos) <> 'array' THEN
        RETURN json_build_object('error', 'Los cobros deben enviarse como una lista', 'registro', NULL);
    END IF;

    SELECT UPPER(COALESCE(est.nombre, '')), c.fecha, c.id_sucursal
    INTO v_estado, v_fecha, v_id_sucursal
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

    -- Los errores por línea abortan con RAISE: así no queda un cambio a medias.
    FOR v_pago IN SELECT * FROM json_array_elements(p_pagos)
    LOOP
        v_id_pago := NULLIF(v_pago ->> 'idPago', '')::INTEGER;

        IF v_id_pago IS NULL THEN
            RAISE EXCEPTION '%', 'Falta el identificador de la línea de cobro';
        END IF;

        SELECT * INTO v_linea
        FROM ven_comprobante_pago
        WHERE id = v_id_pago AND id_comprobante = p_id_comprobante AND estado = 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION '%', format('La línea de cobro %s no pertenece a este comprobante', v_id_pago);
        END IF;

        v_id_medio := COALESCE(NULLIF(v_pago ->> 'idMedioPago', '')::INTEGER, v_linea.id_medio_pago);
        v_cambia_medio := v_id_medio IS DISTINCT FROM v_linea.id_medio_pago;

        IF v_cambia_medio THEN
            IF fin_medio_pago_flag(v_id_medio, 'ES_CREDITO') THEN
                RAISE EXCEPTION '%', 'No se puede cambiar el cobro a crédito: la venta ya se registró como contado.';
            END IF;

            -- Pasar de un medio a otro mueve el arqueo si alguno de los dos afecta caja.
            IF fin_medio_pago_flag(v_linea.id_medio_pago, 'AFECTA_CAJA')
               OR fin_medio_pago_flag(v_id_medio, 'AFECTA_CAJA') THEN
                v_error := fin_caja_assert_abierta(v_fecha, v_id_sucursal);
                IF v_error IS NOT NULL THEN
                    RAISE EXCEPTION '%', 'El cambio de medio de pago afecta la caja del '
                            || to_char(v_fecha, 'DD/MM/YYYY') || '. ' || v_error;
                END IF;
            END IF;

            -- Con otro medio, la cuenta anterior ya no aplica: se toma solo la enviada.
            v_id_cuenta := NULLIF(v_pago ->> 'idCuentaBancaria', '')::INTEGER;
        ELSE
            v_id_cuenta := COALESCE(
                NULLIF(v_pago ->> 'idCuentaBancaria', '')::INTEGER,
                v_linea.id_cuenta_bancaria
            );
        END IF;

        v_error := fin_validar_cuenta_medio_pago(v_id_medio, v_id_cuenta);
        IF v_error IS NOT NULL THEN
            RAISE EXCEPTION '%', v_error;
        END IF;

        UPDATE ven_comprobante_pago
        SET id_medio_pago = v_id_medio,
            numero_operacion = CASE
                WHEN v_cambia_medio
                    THEN NULLIF(TRIM(COALESCE(v_pago ->> 'numeroOperacion', '')), '')
                ELSE COALESCE(
                    NULLIF(TRIM(COALESCE(v_pago ->> 'numeroOperacion', '')), ''),
                    numero_operacion
                )
            END,
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

    -- El medio de la cabecera es el de la línea de mayor monto (igual que al emitir).
    SELECT id_medio_pago INTO v_medio_principal
    FROM ven_comprobante_pago
    WHERE id_comprobante = p_id_comprobante AND estado = 1
    ORDER BY monto DESC, item ASC
    LIMIT 1;

    UPDATE ven_comprobante
    SET id_medio_pago = COALESCE(v_medio_principal, id_medio_pago),
        id_usuario_modificacion = COALESCE(p_id_usuario, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante
      AND id_medio_pago IS DISTINCT FROM COALESCE(v_medio_principal, id_medio_pago);

    RETURN json_build_object(
        'registro', json_build_object(
            'idComprobante', p_id_comprobante,
            'actualizados', v_actualizados,
            'pagos', (ven_obtener_comprobante(p_id_comprobante)) -> 'pagos'
        )
    );
END;
$function$;
