-- ============================================================
-- Migracion: observaciones leves no bloquean el flujo de entrega
-- Fecha: 2026-09-09
-- Solo bloquean PENDIENTE. CON_OBSERVACION queda registrada.
-- ============================================================
-- Function: age_registrar_verificacion
-- Source: migraciones/20260909_age_reparto_flujo_entrega.sql

DROP FUNCTION IF EXISTS age_registrar_verificacion(p_id_actividad integer, p_momento character varying, p_codigos json, p_observacion character varying, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS age_registrar_verificacion(p_id_actividad integer, p_momento character varying, p_lecturas json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_registrar_verificacion(
    p_id_actividad integer,
    p_momento character varying,
    p_lecturas json DEFAULT NULL::json,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_momento        VARCHAR;
    v_es_salida      BOOLEAN;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_id_pendiente   INTEGER;
    v_lectura        JSON;
    v_codigo         VARCHAR;
    v_id_item        INTEGER;
    v_clase          VARCHAR;
    v_conforme       BOOLEAN;
    v_observacion    VARCHAR;
    v_cantidad       NUMERIC;
    v_estado_destino INTEGER;
    v_coincidencias  INTEGER := 0;
    v_ajenos         INTEGER := 0;
    v_pendientes     INTEGER := 0;
    v_observados     INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_momento := UPPER(TRIM(COALESCE(p_momento, '')));

    IF v_momento NOT IN ('SALIDA', 'LLEGADA') THEN
        RETURN json_build_object('error', 'El momento debe ser SALIDA o LLEGADA', 'registro', NULL);
    END IF;

    v_es_salida := v_momento = 'SALIDA';

    IF NOT EXISTS (SELECT 1 FROM age_actividad WHERE id = p_id_actividad AND estado = 1) THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_observado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1 LIMIT 1;

    IF v_id_ok IS NULL THEN
        RETURN json_build_object('error', 'Falta el catalogo EstadoVerificacionItem', 'registro', NULL);
    END IF;

    FOR v_lectura IN
        SELECT x FROM json_array_elements(COALESCE(p_lecturas, '[]'::JSON)) AS a(x)
    LOOP
        v_id_item     := NULL;
        v_clase       := NULL;
        v_codigo      := NULLIF(UPPER(TRIM(COALESCE(v_lectura->>'codigo', ''))), '');
        v_observacion := NULLIF(TRIM(COALESCE(v_lectura->>'observacion', '')), '');
        v_conforme    := COALESCE((v_lectura->>'conforme')::BOOLEAN, TRUE);
        v_cantidad    := NULLIF(v_lectura->>'cantidad', '')::NUMERIC;

        IF v_codigo IS NOT NULL THEN
            -- Cada clase se busca por sus propios codigos. Cruzarlas haria que
            -- escanear el codigo del gas marcara un cilindro, porque el item de
            -- cilindro lleva el gas en id_producto.
            SELECT c.id_item, c.clase INTO v_id_item, v_clase
            FROM age_clasificar_items_actividad(p_id_actividad) c
            JOIN age_actividad_item ai ON ai.id = c.id_item
            LEFT JOIN bal_balon b ON b.id = ai.id_balon
            LEFT JOIN pro_producto p ON p.id = ai.id_producto
            WHERE (
                    c.clase = 'CILINDRO' AND (
                        UPPER(TRIM(COALESCE(b.codigo_balon, ''))) = v_codigo
                        OR UPPER(TRIM(COALESCE(b.numero_serie, ''))) = v_codigo
                    )
                )
               OR (
                    c.clase = 'ACCESORIO' AND (
                        UPPER(TRIM(COALESCE(p.codigo, ''))) = v_codigo
                        OR UPPER(TRIM(COALESCE(p.codigo_barra, ''))) = v_codigo
                    )
                )
            ORDER BY ai.item
            LIMIT 1;

            INSERT INTO age_actividad_verificacion (
                id_actividad, id_actividad_item, momento, codigo_escaneado, coincide,
                observacion, id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                p_id_actividad, v_id_item, v_momento, v_codigo, v_id_item IS NOT NULL,
                v_observacion, p_id_usuario_auditoria, p_id_usuario_auditoria
            );

            IF v_id_item IS NULL THEN
                v_ajenos := v_ajenos + 1;
                CONTINUE;
            END IF;

            -- Un accesorio escaneado suma una unidad; el cilindro se cierra de
            -- una vez porque la linea es el envase mismo.
            IF v_clase = 'ACCESORIO' THEN
                v_cantidad := COALESCE(v_cantidad, 1);
            END IF;

        ELSE
            v_id_item := NULLIF(v_lectura->>'id_item', '')::INTEGER;

            IF v_id_item IS NULL THEN
                CONTINUE;
            END IF;

            SELECT c.clase INTO v_clase
            FROM age_clasificar_items_actividad(p_id_actividad) c
            WHERE c.id_item = v_id_item;

            IF v_clase IS NULL THEN
                v_ajenos := v_ajenos + 1;
                CONTINUE;
            END IF;

            -- El gas no se confirma a mano: sale de sus cilindros mas abajo.
            IF v_clase = 'GAS' THEN
                CONTINUE;
            END IF;
        END IF;

        v_estado_destino := CASE WHEN v_conforme THEN v_id_ok
                                 ELSE COALESCE(v_id_observado, v_id_ok) END;

        IF v_es_salida THEN
            UPDATE age_actividad_item
            SET cantidad_verificada_salida = CASE
                    WHEN v_clase = 'ACCESORIO' AND v_cantidad IS NOT NULL
                        THEN LEAST(cantidad, cantidad_verificada_salida + v_cantidad)
                    WHEN v_clase = 'ACCESORIO' THEN cantidad_verificada_salida
                    ELSE cantidad
                END,
                id_estado_verificacion_salida = CASE
                    -- Un accesorio no queda OK hasta completar su cantidad.
                    WHEN v_clase = 'ACCESORIO'
                         AND LEAST(cantidad, cantidad_verificada_salida + COALESCE(v_cantidad, 0)) < cantidad
                        THEN COALESCE(v_id_pendiente, id_estado_verificacion_salida)
                    ELSE v_estado_destino
                END,
                observacion_salida = COALESCE(v_observacion, observacion_salida),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_item;
        ELSE
            UPDATE age_actividad_item
            SET cantidad_verificada_llegada = CASE
                    WHEN v_clase = 'ACCESORIO' AND v_cantidad IS NOT NULL
                        THEN LEAST(cantidad, cantidad_verificada_llegada + v_cantidad)
                    WHEN v_clase = 'ACCESORIO' THEN cantidad_verificada_llegada
                    ELSE cantidad
                END,
                id_estado_verificacion_llegada = CASE
                    WHEN v_clase = 'ACCESORIO'
                         AND LEAST(cantidad, cantidad_verificada_llegada + COALESCE(v_cantidad, 0)) < cantidad
                        THEN COALESCE(v_id_pendiente, id_estado_verificacion_llegada)
                    ELSE v_estado_destino
                END,
                observacion_llegada = COALESCE(v_observacion, observacion_llegada),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_item;
        END IF;

        v_coincidencias := v_coincidencias + 1;
    END LOOP;

    -- El gas se deriva: queda como el peor estado de los cilindros que lo
    -- transportan, y solo pasa a OK cuando todos ellos estan OK.
    IF v_es_salida THEN
        UPDATE age_actividad_item gas
        SET id_estado_verificacion_salida = d.estado_derivado,
            cantidad_verificada_salida = CASE WHEN d.estado_derivado = v_id_ok THEN gas.cantidad ELSE 0 END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM (
            SELECT
                g.id_item,
                CASE
                    WHEN COUNT(*) FILTER (WHERE ai.id_estado_verificacion_salida IS DISTINCT FROM v_id_ok
                                            AND ai.id_estado_verificacion_salida IS DISTINCT FROM v_id_observado) > 0
                        THEN COALESCE(v_id_pendiente, v_id_ok)
                    WHEN COUNT(*) FILTER (WHERE ai.id_estado_verificacion_salida = v_id_observado) > 0
                        THEN COALESCE(v_id_observado, v_id_ok)
                    ELSE v_id_ok
                END AS estado_derivado
            FROM age_clasificar_items_actividad(p_id_actividad) g
            JOIN age_actividad_item gi ON gi.id = g.id_item
            JOIN age_actividad_item ai ON ai.id_actividad = p_id_actividad AND ai.estado = 1 AND ai.id_balon IS NOT NULL
            JOIN bal_balon b ON b.id = ai.id_balon AND b.id_producto_gas = gi.id_producto
            WHERE g.clase = 'GAS'
            GROUP BY g.id_item
        ) d
        WHERE gas.id = d.id_item;
    ELSE
        UPDATE age_actividad_item gas
        SET id_estado_verificacion_llegada = d.estado_derivado,
            cantidad_verificada_llegada = CASE WHEN d.estado_derivado = v_id_ok THEN gas.cantidad ELSE 0 END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM (
            SELECT
                g.id_item,
                CASE
                    WHEN COUNT(*) FILTER (WHERE ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_ok
                                            AND ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_observado) > 0
                        THEN COALESCE(v_id_pendiente, v_id_ok)
                    WHEN COUNT(*) FILTER (WHERE ai.id_estado_verificacion_llegada = v_id_observado) > 0
                        THEN COALESCE(v_id_observado, v_id_ok)
                    ELSE v_id_ok
                END AS estado_derivado
            FROM age_clasificar_items_actividad(p_id_actividad) g
            JOIN age_actividad_item gi ON gi.id = g.id_item
            JOIN age_actividad_item ai ON ai.id_actividad = p_id_actividad AND ai.estado = 1 AND ai.id_balon IS NOT NULL
            JOIN bal_balon b ON b.id = ai.id_balon AND b.id_producto_gas = gi.id_producto
            WHERE g.clase = 'GAS'
            GROUP BY g.id_item
        ) d
        WHERE gas.id = d.id_item;
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE est IS DISTINCT FROM v_id_ok AND est IS DISTINCT FROM v_id_observado),
        COUNT(*) FILTER (WHERE est = v_id_observado)
    INTO v_pendientes, v_observados
    FROM (
        SELECT CASE WHEN v_es_salida THEN ai.id_estado_verificacion_salida
                    ELSE ai.id_estado_verificacion_llegada END AS est
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id_actividad AND ai.estado = 1
    ) s;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'momento', v_momento,
            'coincidencias', v_coincidencias,
            'no_pertenecen', v_ajenos,
            'pendientes', v_pendientes,
            'observados', v_observados,
            -- completo = se puede avanzar. Solo bloquean los PENDIENTE:
            -- CON_OBSERVACION es un aviso leve (raya, detalle) y queda en la
            -- bitacora, pero no detiene iniciar/culminar la entrega.
            'completo', v_pendientes = 0
        )
    );
END;
$function$;

-- Function: age_iniciar_entrega
-- Source: migraciones/20260909_age_reparto_flujo_entrega.sql

DROP FUNCTION IF EXISTS age_iniciar_entrega(integer, integer);

CREATE OR REPLACE FUNCTION age_iniciar_entrega(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_act            RECORD;
    v_nombre_estado  VARCHAR;
    v_nombre_tipo    VARCHAR;
    v_id_en_ruta     INTEGER;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_id_pend_envio  INTEGER;
    v_id_transito    INTEGER;
    v_items          INTEGER;
    v_pendientes     INTEGER;
    v_observados     INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_trabajador_responsable, a.id_estado_actividad
    INTO v_act
    FROM age_actividad a
    WHERE a.id = p_id AND a.estado = 1;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_estado
    FROM gen_lista_opciones lo WHERE lo.id = v_act.id_estado_actividad;

    SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_tipo
    FROM age_actividad a JOIN gen_lista_opciones lo ON lo.id = a.id_tipo_actividad
    WHERE a.id = p_id;

    IF COALESCE(v_nombre_tipo, '') <> 'REPARTO' THEN
        RETURN json_build_object('error', 'Solo las actividades de REPARTO tienen flujo de entrega', 'registro', NULL);
    END IF;

    IF v_nombre_estado IN ('REALIZADA', 'CANCELADA', 'CANCELADO') THEN
        RETURN json_build_object('error', format('La actividad ya esta %s', v_nombre_estado), 'registro', NULL);
    END IF;

    IF v_nombre_estado = 'EN_RUTA' THEN
        RETURN json_build_object('error', 'La entrega ya esta en ruta', 'registro', NULL);
    END IF;

    -- Sin responsable no hay quien responda por la carga que sale.
    IF v_act.id_trabajador_responsable IS NULL THEN
        RETURN json_build_object('error', 'Asigna un responsable antes de iniciar la entrega', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_en_ruta
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(lo.nombre)) = 'EN_RUTA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_en_ruta IS NULL THEN
        RETURN json_build_object('error', 'No se encontro el estado EN_RUTA en EstadoActividad', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_observado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_salida IS DISTINCT FROM v_id_ok
                           AND ai.id_estado_verificacion_salida IS DISTINCT FROM v_id_observado),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_salida = v_id_observado)
    INTO v_items, v_pendientes, v_observados
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    IF v_items = 0 THEN
        RETURN json_build_object('error', 'La actividad no tiene items que verificar', 'registro', NULL);
    END IF;

    IF v_pendientes > 0 THEN
        RETURN json_build_object(
            'error', format('Faltan %s item(s) por verificar en la salida', v_pendientes),
            'registro', NULL
        );
    END IF;

    -- CON_OBSERVACION no bloquea: es un aviso leve que queda registrado.
    -- Solo los pendientes impiden salir del almacen.

    UPDATE age_actividad
    SET id_estado_actividad = v_id_en_ruta,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- ------------------------------------------------------------
    -- Custodia: PENDIENTE_ENVIO -> EN_TRANSITO
    --
    -- Sin esto el cilindro sigue diciendo "en preparacion, en el almacen"
    -- mientras va en el camion. EN_TRANSITO ya existia en el catalogo, creado
    -- justo para esto ("Se cambia el estado cuando se inicie la actividad") y
    -- nunca cableado.
    --
    -- Como en doc_crear_desde_venta, es un UPDATE directo y no un movimiento de
    -- inventario: el stock ya salio con la venta, registrar otro movimiento lo
    -- contaria dos veces. Esto solo marca donde esta fisicamente el envase.
    --
    -- El camino de vuelta lo hace age_cancelar_actividad. Sin el, un reparto
    -- cancelado dejaria cilindros en transito para siempre.
    -- ------------------------------------------------------------
    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_pend_envio IS NOT NULL AND v_id_transito IS NOT NULL THEN
        UPDATE bal_balon b
        SET id_estado_balon = v_id_transito,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id
          AND ai.estado = 1
          AND ai.id_balon = b.id
          AND b.estado = 1
          AND b.id_estado_balon = v_id_pend_envio;
    END IF;

    RETURN age_obtener_actividad(p_id);
END;
$function$;

-- Function: age_culminar_entrega
-- Source: migraciones/20260909_age_culminar_entrega_custodia.sql

DROP FUNCTION IF EXISTS age_culminar_entrega(integer, integer);

CREATE OR REPLACE FUNCTION age_culminar_entrega(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre_estado  VARCHAR;
    v_id_realizada   INTEGER;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_id_pend_envio  INTEGER;
    v_id_transito    INTEGER;
    v_id_en_poder    INTEGER;
    v_id_cliente     INTEGER;
    v_items          INTEGER;
    v_pendientes     INTEGER;
    v_observados     INTEGER;
    v_cilindros      INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT UPPER(TRIM(lo.nombre)), a.id_cliente
    INTO v_nombre_estado, v_id_cliente
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones lo ON lo.id = a.id_estado_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    -- Culminar exige haber pasado por EN_RUTA: si no, la verificacion de salida
    -- nunca se exigio y la de llegada no prueba nada.
    IF COALESCE(v_nombre_estado, '') <> 'EN_RUTA' THEN
        RETURN json_build_object(
            'error', 'Solo se puede culminar una entrega que este EN_RUTA',
            'registro', NULL
        );
    END IF;

    -- Se acota a la lista EstadoActividad: buscar 'realizada' suelto puede
    -- traer la opcion homonima de otra lista.
    SELECT lo.id INTO v_id_realizada
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(lo.nombre)) = 'REALIZADA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_realizada IS NULL THEN
        RETURN json_build_object('error', 'No se encontro el estado REALIZADA en EstadoActividad', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_observado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_ok
                           AND ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_observado),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_llegada = v_id_observado)
    INTO v_items, v_pendientes, v_observados
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    IF v_pendientes > 0 THEN
        RETURN json_build_object(
            'error', format('Faltan %s item(s) por verificar en la llegada', v_pendientes),
            'registro', NULL
        );
    END IF;

    -- CON_OBSERVACION no bloquea: un araÃ±azo o detalle leve queda en la
    -- bitacora y en el item, pero la entrega puede culminarse.

    UPDATE age_actividad
    SET id_estado_actividad = v_id_realizada,
        fecha_hora_cierre = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- ------------------------------------------------------------
    -- Cierre de custodia: PENDIENTE_ENVIO -> EN_PODER_CLIENTE
    -- ------------------------------------------------------------
    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    -- Lo normal es venir de EN_TRANSITO (lo puso iniciar entrega), pero se
    -- acepta tambien PENDIENTE_ENVIO: hay actividades anteriores a que
    -- existiera el transito, y el catalogo podria faltar en alguna instalacion.
    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_en_poder
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_PODER_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_en_poder IS NOT NULL THEN
        UPDATE bal_balon b
        SET id_estado_balon = v_id_en_poder,
            -- Un cilindro en poder del cliente sin cliente_ubicacion seria un
            -- estado roto; si la venta ya lo apunto, se respeta.
            id_cliente_ubicacion = COALESCE(b.id_cliente_ubicacion, v_id_cliente),
            id_almacen = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id
          AND ai.estado = 1
          AND ai.id_balon = b.id
          AND b.estado = 1
          AND b.id_estado_balon IN (v_id_transito, v_id_pend_envio);

        GET DIAGNOSTICS v_cilindros = ROW_COUNT;
    END IF;

    RETURN age_obtener_actividad(p_id);
END;
$function$;


