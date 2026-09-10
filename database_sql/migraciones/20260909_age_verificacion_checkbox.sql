-- ============================================================
-- Migracion: verificacion checkbox + gates responsable/sesion/EN_RUTA
-- Fecha: 2026-09-09
-- ============================================================
-- Function: age_registrar_verificacion
-- Registra lecturas de verificación (escaneo o confirmación por id_item).
-- pendiente=true revierte el ítem a PENDIENTE (desmarcar checkbox).

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
    v_pendiente      BOOLEAN;
    v_observacion    VARCHAR;
    v_cantidad       NUMERIC;
    v_cantidad_item  NUMERIC;
    v_estado_destino INTEGER;
    v_coincidencias  INTEGER := 0;
    v_ajenos         INTEGER := 0;
    v_pendientes     INTEGER := 0;
    v_observados     INTEGER := 0;
    v_id_trabajador_resp INTEGER;
    v_id_usuario_resp    INTEGER;
    v_id_trabajador_sesion INTEGER;
    v_nombre_estado  VARCHAR;
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

    -- La verificación la responde el responsable asignado (sesión).
    SELECT a.id_trabajador_responsable, a.id_usuario_responsable,
           UPPER(TRIM(ea.nombre))
    INTO v_id_trabajador_resp, v_id_usuario_resp, v_nombre_estado
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
    WHERE a.id = p_id_actividad AND a.estado = 1;

    IF v_nombre_estado IN ('REALIZADA', 'CANCELADA', 'CANCELADO') THEN
        RETURN json_build_object(
            'error', format('No se puede verificar una actividad %s', v_nombre_estado),
            'registro', NULL
        );
    END IF;

    -- Llegada operativa: la carga ya salio / el recojo ya esta en camino.
    IF NOT v_es_salida AND COALESCE(v_nombre_estado, '') <> 'EN_RUTA' THEN
        RETURN json_build_object(
            'error', 'La verificacion de LLEGADA solo aplica cuando la actividad esta EN_RUTA',
            'registro', NULL
        );
    END IF;

    IF v_id_trabajador_resp IS NULL AND v_id_usuario_resp IS NULL THEN
        RETURN json_build_object(
            'error', 'Asigna un responsable antes de verificar (toma la actividad con tu usuario)',
            'registro', NULL
        );
    END IF;

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object(
            'error', 'Se requiere el usuario de sesion para registrar la verificacion',
            'registro', NULL
        );
    END IF;

    SELECT u.id_trabajador INTO v_id_trabajador_sesion
    FROM auth_usuarios u
    WHERE u.id = p_id_usuario_auditoria AND u.estado = TRUE;

    IF NOT (
        (v_id_trabajador_resp IS NOT NULL AND v_id_trabajador_sesion IS NOT NULL
            AND v_id_trabajador_sesion = v_id_trabajador_resp)
        OR (v_id_usuario_resp IS NOT NULL AND p_id_usuario_auditoria = v_id_usuario_resp)
    ) THEN
        RETURN json_build_object(
            'error', 'Solo el responsable asignado (usuario de sesion) puede verificar esta actividad',
            'registro', NULL
        );
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
        v_pendiente   := COALESCE((v_lectura->>'pendiente')::BOOLEAN, FALSE);
        v_cantidad    := NULLIF(v_lectura->>'cantidad', '')::NUMERIC;
        v_cantidad_item := NULL;

        IF v_codigo IS NOT NULL THEN
            SELECT c.id_item, c.clase, ai.cantidad
            INTO v_id_item, v_clase, v_cantidad_item
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

            -- Escaneo marca el ítem completo (accesorio incluido).
            IF v_clase = 'ACCESORIO' THEN
                v_cantidad := COALESCE(v_cantidad, v_cantidad_item);
            END IF;

        ELSE
            v_id_item := NULLIF(v_lectura->>'id_item', '')::INTEGER;

            IF v_id_item IS NULL THEN
                CONTINUE;
            END IF;

            SELECT c.clase, ai.cantidad
            INTO v_clase, v_cantidad_item
            FROM age_clasificar_items_actividad(p_id_actividad) c
            JOIN age_actividad_item ai ON ai.id = c.id_item
            WHERE c.id_item = v_id_item;

            IF v_clase IS NULL THEN
                v_ajenos := v_ajenos + 1;
                CONTINUE;
            END IF;

            IF v_clase = 'GAS' THEN
                CONTINUE;
            END IF;

            IF v_clase = 'ACCESORIO' THEN
                v_cantidad := COALESCE(v_cantidad, v_cantidad_item);
            END IF;
        END IF;

        -- Desmarcar: vuelve a Pendiente para reverificar.
        IF v_pendiente THEN
            IF v_es_salida THEN
                UPDATE age_actividad_item
                SET cantidad_verificada_salida = 0,
                    id_estado_verificacion_salida = COALESCE(v_id_pendiente, id_estado_verificacion_salida),
                    observacion_salida = NULL,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_item;
            ELSE
                UPDATE age_actividad_item
                SET cantidad_verificada_llegada = 0,
                    id_estado_verificacion_llegada = COALESCE(v_id_pendiente, id_estado_verificacion_llegada),
                    observacion_llegada = NULL,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_item;
            END IF;

            v_coincidencias := v_coincidencias + 1;
            CONTINUE;
        END IF;

        v_estado_destino := CASE WHEN v_conforme THEN v_id_ok
                                 ELSE COALESCE(v_id_observado, v_id_ok) END;

        IF v_es_salida THEN
            UPDATE age_actividad_item
            SET cantidad_verificada_salida = CASE
                    WHEN v_clase = 'ACCESORIO'
                        THEN LEAST(cantidad, COALESCE(v_cantidad, cantidad))
                    ELSE cantidad
                END,
                id_estado_verificacion_salida = CASE
                    WHEN v_clase = 'ACCESORIO'
                         AND LEAST(cantidad, COALESCE(v_cantidad, cantidad)) < cantidad
                        THEN COALESCE(v_id_pendiente, id_estado_verificacion_salida)
                    ELSE v_estado_destino
                END,
                observacion_salida = CASE
                    WHEN v_conforme THEN NULL
                    ELSE COALESCE(v_observacion, observacion_salida)
                END,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_item;
        ELSE
            UPDATE age_actividad_item
            SET cantidad_verificada_llegada = CASE
                    WHEN v_clase = 'ACCESORIO'
                        THEN LEAST(cantidad, COALESCE(v_cantidad, cantidad))
                    ELSE cantidad
                END,
                id_estado_verificacion_llegada = CASE
                    WHEN v_clase = 'ACCESORIO'
                         AND LEAST(cantidad, COALESCE(v_cantidad, cantidad)) < cantidad
                        THEN COALESCE(v_id_pendiente, id_estado_verificacion_llegada)
                    ELSE v_estado_destino
                END,
                observacion_llegada = CASE
                    WHEN v_conforme THEN NULL
                    ELSE COALESCE(v_observacion, observacion_llegada)
                END,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_item;
        END IF;

        v_coincidencias := v_coincidencias + 1;
    END LOOP;

    -- El gas se deriva del peor estado de sus cilindros.
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
            'completo', v_pendientes = 0
        )
    );
END;
$function$;
