-- Function: ven_sincronizar_pagos_comprobante
-- Fase 3 — punto único de escritura de ven_comprobante_pago.
--
-- Recibe el conjunto completo de líneas de cobro de una venta y lo aplica de
-- golpe (borra las anteriores e inserta las nuevas), de modo que crear y editar
-- un comprobante usan el mismo camino.
--
-- Además mantiene `ven_comprobante.id_medio_pago` como derivado de conveniencia:
-- guarda el medio de la línea de mayor monto. Es lo que siguen leyendo los
-- listados y los reportes que muestran "un" medio por venta; el dato fino vive
-- en las líneas.
--
-- p_pagos: JSON array de objetos
--     [{"idMedioPago":265,"monto":50.00},
--      {"idMedioPago":266,"monto":100.00,"idCuentaBancaria":16,"numeroOperacion":"OP-1"}]
--   NULL  -> no toca nada (el comprobante sigue con su medio de cabecera).
--   []    -> borra las líneas y deja la venta sin desglose.
--
-- En una lista de un solo elemento el `monto` puede omitirse y se toma el total
-- del comprobante. Es el caso del POS, donde se cobra todo con un medio: así
-- cada panel manda medio y cuenta sin tener que recalcular el total, que ya
-- calculó el propio orquestador de la venta.
--
-- Devuelve NULL si todo fue bien, o el mensaje de error (convención de
-- fin_caja_assert_abierta / fin_validar_cuenta_medio_pago).

DROP FUNCTION IF EXISTS ven_sincronizar_pagos_comprobante(p_id_comprobante integer, p_pagos json, p_id_usuario integer);

CREATE OR REPLACE FUNCTION ven_sincronizar_pagos_comprobante(
    p_id_comprobante integer,
    p_pagos json DEFAULT NULL::json,
    p_id_usuario integer DEFAULT NULL::integer
)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
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

    -- ---------------------------------------------------------------------
    -- Primera pasada: validar TODO antes de tocar nada.
    -- ---------------------------------------------------------------------
    -- El borrado de las líneas anteriores va después de validar a propósito.
    -- Si se borrase primero, un rechazo dejaría el comprobante sin desglose
    -- cuando el llamador se limita a leer el mensaje de error en vez de
    -- propagarlo como excepción.
    v_total_pagos := 0;

    FOR v_pago IN SELECT * FROM json_array_elements(p_pagos)
    LOOP
        v_item := v_item + 1;
        v_id_medio  := NULLIF(v_pago ->> 'idMedioPago', '')::INTEGER;
        v_id_cuenta := NULLIF(v_pago ->> 'idCuentaBancaria', '')::INTEGER;
        -- Monto omitido en una lista de un solo pago = el total del comprobante.
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

        -- El número de operación NO bloquea la venta aunque el medio lo tenga
        -- marcado en fin_medio_pago_config. Los únicos llamadores de esta
        -- función son el POS (ven_crear_comprobante, bal_crear_recarga_cliente)
        -- y la edición de un comprobante: en el mostrador el cajero no siempre
        -- tiene el voucher a la vista al cobrar, y frenar la venta por eso es
        -- peor que registrarla y completar el dato después. Lo que sí es
        -- innegociable es la cuenta bancaria, que valida
        -- fin_validar_cuenta_medio_pago más arriba: sin ella el dinero no se
        -- puede conciliar con el banco.

        v_total_pagos := v_total_pagos + v_monto;
    END LOOP;

    -- La suma de los cobros tiene que ser el total de la venta: si no, la caja
    -- cuadraría contra un importe que nadie pagó. Se tolera el céntimo de
    -- redondeo del reparto entre medios.
    IF json_array_length(p_pagos) > 0
       AND ABS(v_total_pagos - COALESCE(v_total_comprobante, 0)) > 0.01 THEN
        RETURN format(
            'Los pagos suman %s y el comprobante es de %s. Deben coincidir.',
            gen_formato_cantidad(v_total_pagos),
            gen_formato_cantidad(COALESCE(v_total_comprobante, 0))
        );
    END IF;

    -- ---------------------------------------------------------------------
    -- Segunda pasada: ya validado, se reemplaza el desglose.
    -- ---------------------------------------------------------------------
    -- Se usa DELETE y no `estado = 0` porque ven_pagos_de_comprobante decide
    -- entre líneas y cabecera según existan líneas activas: dejar filas
    -- anuladas no aportaría nada y complicaría esa decisión.
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
