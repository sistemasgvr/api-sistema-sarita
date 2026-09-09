-- Probe E2E de age_registrar_verificacion.
-- Corre dentro de una transaccion que SIEMPRE aborta: el exito esperado es
-- RAISE EXCEPTION '--- E2E OK (revertido) ---' (exit 1 del runner).
-- No deja filas permanentes (los sequences de PG si avanzan; es normal).

DO $probe$
DECLARE
    v_id_ok            INTEGER;
    v_id_obs           INTEGER;
    v_id_pend          INTEGER;
    v_id_tipo          INTEGER;
    v_id_prio          INTEGER;
    v_id_estado        INTEGER;
    v_id_cliente       INTEGER;
    v_id_balon         INTEGER;
    v_cod_balon        VARCHAR;
    v_id_gas           INTEGER;
    v_cod_gas          VARCHAR;
    v_id_acc           INTEGER;
    v_cod_acc          VARCHAR;
    v_id_act           INTEGER;
    v_id_cil           INTEGER;
    v_id_item_gas      INTEGER;
    v_id_item_acc      INTEGER;
    v_clase_cil        VARCHAR;
    v_clase_gas        VARCHAR;
    v_clase_acc        VARCHAR;
    v_res              JSON;
    v_est_cil          INTEGER;
    v_est_gas          INTEGER;
    v_est_acc          INTEGER;
    v_qty_acc          NUMERIC;
    v_bit_ok           INTEGER;
    v_bit_ajeno        INTEGER;
BEGIN
    -- Catalogos
    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;
    SELECT lo.id INTO v_id_obs
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;
    SELECT lo.id INTO v_id_pend
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1 LIMIT 1;

    IF v_id_ok IS NULL OR v_id_obs IS NULL OR v_id_pend IS NULL THEN
        RAISE EXCEPTION 'E2E FAIL: falta catalogo EstadoVerificacionItem (OK/CON_OBSERVACION/PENDIENTE)';
    END IF;

    SELECT lo.id INTO v_id_tipo
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'TipoActividad' OR l.id = 48) AND UPPER(TRIM(lo.nombre)) = 'REPARTO' AND lo.estado = 1 LIMIT 1;
    SELECT lo.id INTO v_id_prio
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'PrioridadActividad' OR l.id = 50) AND lo.estado = 1 LIMIT 1;
    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49) AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE' AND lo.estado = 1 LIMIT 1;
    SELECT id INTO v_id_cliente FROM cli_clientes WHERE estado = 1 ORDER BY id LIMIT 1;

    IF v_id_tipo IS NULL OR v_id_prio IS NULL OR v_id_estado IS NULL OR v_id_cliente IS NULL THEN
        RAISE EXCEPTION 'E2E FAIL: faltan tipo/prioridad/estado/cliente para el fixture';
    END IF;

    -- Cilindro con codigo y gas asociado
    SELECT b.id, NULLIF(UPPER(TRIM(COALESCE(b.codigo_balon, b.numero_serie, ''))), ''), b.id_producto_gas
    INTO v_id_balon, v_cod_balon, v_id_gas
    FROM bal_balon b
    WHERE b.estado = 1
      AND b.id_producto_gas IS NOT NULL
      AND NULLIF(TRIM(COALESCE(b.codigo_balon, b.numero_serie, '')), '') IS NOT NULL
    ORDER BY b.id
    LIMIT 1;

    IF v_id_balon IS NULL OR v_cod_balon IS NULL OR v_id_gas IS NULL THEN
        RAISE EXCEPTION 'E2E FAIL: no hay balon vigente con codigo y id_producto_gas';
    END IF;

    SELECT NULLIF(UPPER(TRIM(COALESCE(p.codigo, p.codigo_barra, ''))), '')
    INTO v_cod_gas
    FROM pro_producto p WHERE p.id = v_id_gas;

    -- Accesorio: producto vigente que NO es el gas del cilindro
    SELECT p.id, NULLIF(UPPER(TRIM(COALESCE(p.codigo, p.codigo_barra, ''))), '')
    INTO v_id_acc, v_cod_acc
    FROM pro_producto p
    WHERE p.estado = 1
      AND p.id <> v_id_gas
      AND NULLIF(TRIM(COALESCE(p.codigo, p.codigo_barra, '')), '') IS NOT NULL
    ORDER BY p.id
    LIMIT 1;

    IF v_id_acc IS NULL THEN
        RAISE EXCEPTION 'E2E FAIL: no hay producto accesorio distinto del gas';
    END IF;

    INSERT INTO age_actividad (
        titulo, fecha_programada, hora_inicio_estimada, hora_fin_estimada,
        id_tipo_actividad, id_prioridad, id_cliente, id_estado_actividad
    ) VALUES (
        '[PROBE E2E] verificar ' || to_char(clock_timestamp(), 'HH24MISS'),
        CURRENT_DATE, TIME '08:00', TIME '10:00',
        v_id_tipo, v_id_prio, v_id_cliente, v_id_estado
    ) RETURNING id INTO v_id_act;

    INSERT INTO age_actividad_item (id_actividad, item, id_producto, cantidad, id_balon, id_estado_verificacion_salida, id_estado_verificacion_llegada)
    VALUES (v_id_act, 1, NULL, 1, v_id_balon, v_id_pend, v_id_pend)
    RETURNING id INTO v_id_cil;

    INSERT INTO age_actividad_item (id_actividad, item, id_producto, cantidad, id_balon, id_estado_verificacion_salida, id_estado_verificacion_llegada)
    VALUES (v_id_act, 2, v_id_gas, 1, NULL, v_id_pend, v_id_pend)
    RETURNING id INTO v_id_item_gas;

    INSERT INTO age_actividad_item (id_actividad, item, id_producto, cantidad, id_balon, id_estado_verificacion_salida, id_estado_verificacion_llegada)
    VALUES (v_id_act, 3, v_id_acc, 2, NULL, v_id_pend, v_id_pend)
    RETURNING id INTO v_id_item_acc;

    SELECT clase INTO v_clase_cil FROM age_clasificar_items_actividad(v_id_act) WHERE id_item = v_id_cil;
    SELECT clase INTO v_clase_gas FROM age_clasificar_items_actividad(v_id_act) WHERE id_item = v_id_item_gas;
    SELECT clase INTO v_clase_acc FROM age_clasificar_items_actividad(v_id_act) WHERE id_item = v_id_item_acc;

    IF v_clase_cil IS DISTINCT FROM 'CILINDRO' OR v_clase_gas IS DISTINCT FROM 'GAS' OR v_clase_acc IS DISTINCT FROM 'ACCESORIO' THEN
        RAISE EXCEPTION 'E2E FAIL: clasificacion % / % / % (esperado CILINDRO/GAS/ACCESORIO)', v_clase_cil, v_clase_gas, v_clase_acc;
    END IF;

    RAISE NOTICE 'fixture act=% cil=% gas=% acc=% cod_balon=%', v_id_act, v_id_cil, v_id_item_gas, v_id_item_acc, v_cod_balon;

    -- 1) momento invalido
    v_res := age_registrar_verificacion(v_id_act, 'FOO', '[]'::JSON, NULL);
    IF v_res->>'error' IS NULL THEN
        RAISE EXCEPTION 'E2E FAIL: momento invalido debio error, got %', v_res;
    END IF;

    -- 2) actividad inexistente
    v_res := age_registrar_verificacion(-1, 'SALIDA', '[]'::JSON, NULL);
    IF v_res->>'error' IS NULL THEN
        RAISE EXCEPTION 'E2E FAIL: actividad inexistente debio error, got %', v_res;
    END IF;

    -- 3) codigo ajeno + escaneo del cilindro
    v_res := age_registrar_verificacion(
        v_id_act,
        'SALIDA',
        json_build_array(
            json_build_object('codigo', 'CODIGO-AJENO-PROBE-E2E', 'conforme', true),
            json_build_object('codigo', v_cod_balon, 'conforme', true)
        ),
        NULL
    );
    IF v_res->>'error' IS NOT NULL THEN
        RAISE EXCEPTION 'E2E FAIL: SALIDA cilindro+ajeno error=%', v_res->>'error';
    END IF;
    IF (v_res->'registro'->>'coincidencias')::INT <> 1 THEN
        RAISE EXCEPTION 'E2E FAIL: coincidencias esperadas 1, got %', v_res;
    END IF;
    IF (v_res->'registro'->>'no_pertenecen')::INT <> 1 THEN
        RAISE EXCEPTION 'E2E FAIL: no_pertenecen esperados 1, got %', v_res;
    END IF;
    IF (v_res->'registro'->>'completo')::BOOLEAN IS NOT FALSE THEN
        RAISE EXCEPTION 'E2E FAIL: no deberia estar completo con accesorio pendiente, got %', v_res;
    END IF;

    SELECT id_estado_verificacion_salida INTO v_est_cil FROM age_actividad_item WHERE id = v_id_cil;
    SELECT id_estado_verificacion_salida INTO v_est_gas FROM age_actividad_item WHERE id = v_id_item_gas;
    SELECT id_estado_verificacion_salida INTO v_est_acc FROM age_actividad_item WHERE id = v_id_item_acc;

    IF v_est_cil IS DISTINCT FROM v_id_ok THEN
        RAISE EXCEPTION 'E2E FAIL: cilindro SALIDA no quedo OK (estado=%)', v_est_cil;
    END IF;
    IF v_est_gas IS DISTINCT FROM v_id_ok THEN
        RAISE EXCEPTION 'E2E FAIL: gas SALIDA no derivo a OK (estado=%). El gas no se escanea, se deriva del cilindro.', v_est_gas;
    END IF;
    IF v_est_acc IS DISTINCT FROM v_id_pend THEN
        RAISE EXCEPTION 'E2E FAIL: accesorio no debio cambiar aun (estado=%)', v_est_acc;
    END IF;

    SELECT COUNT(*) INTO v_bit_ajeno
    FROM age_actividad_verificacion
    WHERE id_actividad = v_id_act AND coincide IS FALSE AND codigo_escaneado = 'CODIGO-AJENO-PROBE-E2E';
    SELECT COUNT(*) INTO v_bit_ok
    FROM age_actividad_verificacion
    WHERE id_actividad = v_id_act AND coincide IS TRUE AND id_actividad_item = v_id_cil;
    IF v_bit_ajeno <> 1 OR v_bit_ok < 1 THEN
        RAISE EXCEPTION 'E2E FAIL: bitacora ajeno=% coincidencia_cil=%', v_bit_ajeno, v_bit_ok;
    END IF;

    -- 4) escanear el codigo del GAS no debe marcar el cilindro de nuevo ni el gas como lectura
    --    (cruzar clases haria que el codigo del gas pegara al cilindro por id_producto).
    --    Si v_cod_gas es null se omite.
    IF v_cod_gas IS NOT NULL AND v_cod_gas IS DISTINCT FROM v_cod_balon AND v_cod_gas IS DISTINCT FROM v_cod_acc THEN
        v_res := age_registrar_verificacion(
            v_id_act,
            'SALIDA',
            json_build_array(json_build_object('codigo', v_cod_gas, 'conforme', true)),
            NULL
        );
        IF v_res->>'error' IS NOT NULL THEN
            RAISE EXCEPTION 'E2E FAIL: scan codigo gas error=%', v_res->>'error';
        END IF;
        -- El codigo del gas no pertenece a CILINDRO ni ACCESORIO → ajeno
        IF (v_res->'registro'->>'no_pertenecen')::INT < 1 THEN
            RAISE EXCEPTION 'E2E FAIL: codigo de gas no deberia matchear cilindro/accesorio, got %', v_res;
        END IF;
    END IF;

    -- 5) accesorio parcial (1 de 2) sigue PENDIENTE
    v_res := age_registrar_verificacion(
        v_id_act,
        'SALIDA',
        json_build_array(json_build_object('id_item', v_id_item_acc, 'cantidad', 1, 'conforme', true)),
        NULL
    );
    IF v_res->>'error' IS NOT NULL THEN
        RAISE EXCEPTION 'E2E FAIL: accesorio parcial error=%', v_res->>'error';
    END IF;
    SELECT id_estado_verificacion_salida, cantidad_verificada_salida
    INTO v_est_acc, v_qty_acc
    FROM age_actividad_item WHERE id = v_id_item_acc;
    IF v_est_acc IS DISTINCT FROM v_id_pend THEN
        RAISE EXCEPTION 'E2E FAIL: accesorio 1/2 debio seguir PENDIENTE, estado=%', v_est_acc;
    END IF;
    IF v_qty_acc IS DISTINCT FROM 1 THEN
        RAISE EXCEPTION 'E2E FAIL: cantidad_verificada_salida esperada 1, got %', v_qty_acc;
    END IF;
    IF (v_res->'registro'->>'completo')::BOOLEAN IS NOT FALSE THEN
        RAISE EXCEPTION 'E2E FAIL: 1/2 no es completo, got %', v_res;
    END IF;

    -- 6) completar accesorio → SALIDA completa
    v_res := age_registrar_verificacion(
        v_id_act,
        'SALIDA',
        json_build_array(json_build_object('id_item', v_id_item_acc, 'cantidad', 1, 'conforme', true)),
        NULL
    );
    IF v_res->>'error' IS NOT NULL THEN
        RAISE EXCEPTION 'E2E FAIL: accesorio cierre error=%', v_res->>'error';
    END IF;
    SELECT id_estado_verificacion_salida, cantidad_verificada_salida
    INTO v_est_acc, v_qty_acc
    FROM age_actividad_item WHERE id = v_id_item_acc;
    IF v_est_acc IS DISTINCT FROM v_id_ok THEN
        RAISE EXCEPTION 'E2E FAIL: accesorio 2/2 debio OK, estado=%', v_est_acc;
    END IF;
    IF v_qty_acc IS DISTINCT FROM 2 THEN
        RAISE EXCEPTION 'E2E FAIL: cantidad_verificada_salida esperada 2, got %', v_qty_acc;
    END IF;
    IF (v_res->'registro'->>'completo')::BOOLEAN IS NOT TRUE THEN
        RAISE EXCEPTION 'E2E FAIL: SALIDA debio quedar completa, got %', v_res;
    END IF;
    IF (v_res->'registro'->>'pendientes')::INT <> 0 OR (v_res->'registro'->>'observados')::INT <> 0 THEN
        RAISE EXCEPTION 'E2E FAIL: SALIDA completa con pendientes/observados, got %', v_res;
    END IF;

    -- 7) LLEGADA cilindro CON_OBSERVACION → gas observado, no completo
    v_res := age_registrar_verificacion(
        v_id_act,
        'LLEGADA',
        json_build_array(json_build_object(
            'codigo', v_cod_balon,
            'conforme', false,
            'observacion', 'abolladura probe e2e'
        )),
        NULL
    );
    IF v_res->>'error' IS NOT NULL THEN
        RAISE EXCEPTION 'E2E FAIL: LLEGADA observado error=%', v_res->>'error';
    END IF;
    SELECT id_estado_verificacion_llegada, observacion_llegada INTO v_est_cil, v_cod_gas
    FROM age_actividad_item WHERE id = v_id_cil;
    SELECT id_estado_verificacion_llegada INTO v_est_gas FROM age_actividad_item WHERE id = v_id_item_gas;
    IF v_est_cil IS DISTINCT FROM v_id_obs THEN
        RAISE EXCEPTION 'E2E FAIL: cilindro LLEGADA debio CON_OBSERVACION, estado=%', v_est_cil;
    END IF;
    IF v_est_gas IS DISTINCT FROM v_id_obs THEN
        RAISE EXCEPTION 'E2E FAIL: gas LLEGADA debio derivar CON_OBSERVACION, estado=%', v_est_gas;
    END IF;
    IF (v_res->'registro'->>'completo')::BOOLEAN IS NOT FALSE THEN
        RAISE EXCEPTION 'E2E FAIL: observado no es completo (gate estricto), got %', v_res;
    END IF;
    IF (v_res->'registro'->>'observados')::INT < 1 THEN
        RAISE EXCEPTION 'E2E FAIL: debio contar observados, got %', v_res;
    END IF;

    -- 8) resolver observacion re-verificando conforme + completar accesorio LLEGADA
    --    (si hay codigo de accesorio se prueba tambien el scan por producto)
    IF v_cod_acc IS NOT NULL AND v_cod_acc IS DISTINCT FROM v_cod_balon THEN
        v_res := age_registrar_verificacion(
            v_id_act,
            'LLEGADA',
            json_build_array(
                json_build_object('codigo', v_cod_balon, 'conforme', true),
                json_build_object('codigo', v_cod_acc, 'cantidad', 2, 'conforme', true)
            ),
            NULL
        );
    ELSE
        v_res := age_registrar_verificacion(
            v_id_act,
            'LLEGADA',
            json_build_array(
                json_build_object('codigo', v_cod_balon, 'conforme', true),
                json_build_object('id_item', v_id_item_acc, 'cantidad', 2, 'conforme', true)
            ),
            NULL
        );
    END IF;
    IF v_res->>'error' IS NOT NULL THEN
        RAISE EXCEPTION 'E2E FAIL: LLEGADA resolver error=%', v_res->>'error';
    END IF;
    SELECT id_estado_verificacion_llegada INTO v_est_cil FROM age_actividad_item WHERE id = v_id_cil;
    SELECT id_estado_verificacion_llegada INTO v_est_gas FROM age_actividad_item WHERE id = v_id_item_gas;
    SELECT id_estado_verificacion_llegada INTO v_est_acc FROM age_actividad_item WHERE id = v_id_item_acc;
    IF v_est_cil IS DISTINCT FROM v_id_ok OR v_est_gas IS DISTINCT FROM v_id_ok OR v_est_acc IS DISTINCT FROM v_id_ok THEN
        RAISE EXCEPTION 'E2E FAIL: LLEGADA no quedo OK cil=% gas=% acc=%', v_est_cil, v_est_gas, v_est_acc;
    END IF;
    IF (v_res->'registro'->>'completo')::BOOLEAN IS NOT TRUE THEN
        RAISE EXCEPTION 'E2E FAIL: LLEGADA debio quedar completa, got %', v_res;
    END IF;

    RAISE EXCEPTION '--- E2E OK (revertido) --- act=% cil=% gas=% acc=%', v_id_act, v_id_cil, v_id_item_gas, v_id_item_acc;
END
$probe$;
