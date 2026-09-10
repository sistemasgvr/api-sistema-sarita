-- ============================================================
-- Migracion: auditoria integridad actividades (P0/P1 audit fixes)
-- Fecha: 2026-09-09
-- JWT fuerza auditoria en Nest; estas funciones endurecen SQL.
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


-- Function: age_iniciar_verificacion
-- Source: migraciones/20260909_age_reparto_flujo_entrega.sql

DROP FUNCTION IF EXISTS age_iniciar_verificacion(integer, integer);

CREATE OR REPLACE FUNCTION age_iniciar_verificacion(
    p_id_actividad integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_act RECORD;
    v_id_pendiente INTEGER;
    v_items INTEGER := 0;
    v_n INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_prestamo, a.id_alquiler, a.id_doc_salida, a.id_comprobante,
           a.id_trabajador_responsable
    INTO v_act
    FROM age_actividad a
    WHERE a.id = p_id_actividad AND a.estado = 1;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM age_actividad_item i
        WHERE i.id_actividad = p_id_actividad AND i.estado = 1
    ) THEN
        RETURN age_obtener_actividad(p_id_actividad);
    END IF;

    IF v_act.id_trabajador_responsable IS NULL THEN
        RETURN json_build_object(
            'error', 'Asigna un responsable antes de iniciar la verificacion',
            'registro', NULL
        );
    END IF;

    IF p_id_usuario_auditoria IS NOT NULL THEN
        DECLARE
            v_id_trabajador_sesion INTEGER;
        BEGIN
            SELECT u.id_trabajador INTO v_id_trabajador_sesion
            FROM auth_usuarios u
            WHERE u.id = p_id_usuario_auditoria AND u.estado = TRUE;

            IF v_id_trabajador_sesion IS NULL
               OR v_id_trabajador_sesion IS DISTINCT FROM v_act.id_trabajador_responsable THEN
                RETURN json_build_object(
                    'error', 'Solo el responsable asignado (usuario de sesion) puede iniciar la verificacion',
                    'registro', NULL
                );
            END IF;
        END;
    END IF;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_act.id_prestamo IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_prestamo_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_actividad,
            ROW_NUMBER() OVER (ORDER BY pd.id),
            COALESCE(pd.id_producto, b.id_producto_gas),
            COALESCE(b.codigo_balon, 'Cilindro'),
            1,
            pd.id_balon,
            pd.id,
            v_id_pendiente,
            v_id_pendiente,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM bal_prestamo_detalle pd
        LEFT JOIN bal_balon b ON b.id = pd.id_balon
        WHERE pd.id_prestamo = v_act.id_prestamo
          AND pd.estado = 1
          AND pd.fecha_devolucion IS NULL
          AND pd.id_balon IS NOT NULL;
        GET DIAGNOSTICS v_items = ROW_COUNT;
    ELSIF v_act.id_alquiler IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_alquiler_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_actividad,
            ROW_NUMBER() OVER (ORDER BY ad.id),
            b.id_producto_gas,
            COALESCE(b.codigo_balon, 'Cilindro'),
            1,
            ad.id_balon,
            ad.id,
            v_id_pendiente,
            v_id_pendiente,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM bal_alquiler_detalle ad
        LEFT JOIN bal_balon b ON b.id = ad.id_balon
        WHERE ad.id_alquiler = v_act.id_alquiler
          AND ad.estado = 1
          AND ad.fecha_devolucion IS NULL
          AND ad.id_balon IS NOT NULL;
        GET DIAGNOSTICS v_items = ROW_COUNT;

        -- Regulador pendiente: fila sin balon, solo producto.
        IF EXISTS (
            SELECT 1 FROM bal_alquiler a
            WHERE a.id = v_act.id_alquiler
              AND a.id_producto_regulador IS NOT NULL
              AND a.fecha_devolucion_regulador IS NULL
        ) THEN
            SELECT COALESCE(MAX(item), 0) INTO v_n
            FROM age_actividad_item
            WHERE id_actividad = p_id_actividad AND estado = 1;

            INSERT INTO age_actividad_item (
                id_actividad, item, id_producto, descripcion, cantidad, id_balon,
                id_estado_verificacion_salida, id_estado_verificacion_llegada,
                id_usuario_creacion, id_usuario_modificacion
            )
            SELECT
                p_id_actividad,
                v_n + 1,
                a.id_producto_regulador,
                COALESCE(pr.nombre, 'Regulador / accesorio'),
                1,
                NULL,
                v_id_pendiente,
                v_id_pendiente,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            FROM bal_alquiler a
            LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
            WHERE a.id = v_act.id_alquiler;

            v_items := v_items + 1;
        END IF;
    ELSIF v_act.id_doc_salida IS NOT NULL OR v_act.id_comprobante IS NOT NULL THEN
        -- REPARTO sin items materializados: no hay nada que derivar aqui, los
        -- items los crea age_crear_actividad desde el detalle del documento.
        RETURN json_build_object(
            'error', 'La actividad de reparto no tiene items: revisa el documento de origen',
            'registro', NULL
        );
    ELSE
        RETURN json_build_object(
            'error', 'La actividad no tiene origen del que derivar items',
            'registro', NULL
        );
    END IF;

    RETURN age_obtener_actividad(p_id_actividad);
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
    v_cilindros_tot  INTEGER := 0;
    v_cilindros_esp  INTEGER := 0;
    v_cilindros_upd  INTEGER := 0;
    v_id_trabajador_sesion INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_trabajador_responsable, a.id_usuario_responsable, a.id_estado_actividad
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

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object(
            'error', 'Se requiere el usuario de sesion para iniciar la entrega',
            'registro', NULL
        );
    END IF;

    SELECT u.id_trabajador INTO v_id_trabajador_sesion
    FROM auth_usuarios u
    WHERE u.id = p_id_usuario_auditoria AND u.estado = TRUE;

    IF NOT (
        (v_act.id_trabajador_responsable IS NOT NULL AND v_id_trabajador_sesion IS NOT NULL
            AND v_id_trabajador_sesion = v_act.id_trabajador_responsable)
        OR (v_act.id_usuario_responsable IS NOT NULL AND p_id_usuario_auditoria = v_act.id_usuario_responsable)
    ) THEN
        RETURN json_build_object(
            'error', 'Solo el responsable asignado (usuario de sesion) puede iniciar esta entrega',
            'registro', NULL
        );
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

    IF v_id_pend_envio IS NULL OR v_id_transito IS NULL THEN
        RETURN json_build_object(
            'error', 'Faltan estados PENDIENTE_ENVIO o EN_TRANSITO en catalogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE ai.id_balon IS NOT NULL),
        COUNT(*) FILTER (WHERE ai.id_balon IS NOT NULL AND b.id_estado_balon = v_id_pend_envio)
    INTO v_cilindros_tot, v_cilindros_esp
    FROM age_actividad_item ai
    LEFT JOIN bal_balon b ON b.id = ai.id_balon AND b.estado = 1
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    -- Accesorios-only: sin cilindros no se exige custodia.
    IF v_cilindros_tot > 0 AND v_cilindros_esp = 0 THEN
        RETURN json_build_object(
            'error', 'Los cilindros de la actividad no estan en PENDIENTE_ENVIO; no se puede iniciar la entrega',
            'registro', NULL
        );
    END IF;

    -- Custodia primero: si falla, la actividad no queda EN_RUTA a medias.
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

    GET DIAGNOSTICS v_cilindros_upd = ROW_COUNT;

    IF v_cilindros_esp > 0 AND v_cilindros_upd = 0 THEN
        RETURN json_build_object(
            'error', format(
                'No se actualizo ningun cilindro a EN_TRANSITO (se esperaban %s en PENDIENTE_ENVIO)',
                v_cilindros_esp
            ),
            'registro', NULL
        );
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_en_ruta,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

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
    v_act            RECORD;
    v_nombre_estado  VARCHAR;
    v_id_realizada   INTEGER;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_id_pend_envio  INTEGER;
    v_id_transito    INTEGER;
    v_id_en_poder    INTEGER;
    v_items          INTEGER;
    v_pendientes     INTEGER;
    v_observados     INTEGER;
    v_cilindros_tot  INTEGER := 0;
    v_cilindros_esp  INTEGER := 0;
    v_cilindros_upd  INTEGER := 0;
    v_id_trabajador_sesion INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_cliente, a.id_trabajador_responsable, a.id_usuario_responsable,
           UPPER(TRIM(lo.nombre)) AS nombre_estado
    INTO v_act
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones lo ON lo.id = a.id_estado_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    v_nombre_estado := v_act.nombre_estado;

    -- Culminar exige haber pasado por EN_RUTA: si no, la verificacion de salida
    -- nunca se exigio y la de llegada no prueba nada.
    IF COALESCE(v_nombre_estado, '') <> 'EN_RUTA' THEN
        RETURN json_build_object(
            'error', 'Solo se puede culminar una entrega que este EN_RUTA',
            'registro', NULL
        );
    END IF;

    IF v_act.id_trabajador_responsable IS NULL AND v_act.id_usuario_responsable IS NULL THEN
        RETURN json_build_object(
            'error', 'Asigna un responsable antes de culminar la entrega',
            'registro', NULL
        );
    END IF;

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object(
            'error', 'Se requiere el usuario de sesion para culminar la entrega',
            'registro', NULL
        );
    END IF;

    SELECT u.id_trabajador INTO v_id_trabajador_sesion
    FROM auth_usuarios u
    WHERE u.id = p_id_usuario_auditoria AND u.estado = TRUE;

    IF NOT (
        (v_act.id_trabajador_responsable IS NOT NULL AND v_id_trabajador_sesion IS NOT NULL
            AND v_id_trabajador_sesion = v_act.id_trabajador_responsable)
        OR (v_act.id_usuario_responsable IS NOT NULL AND p_id_usuario_auditoria = v_act.id_usuario_responsable)
    ) THEN
        RETURN json_build_object(
            'error', 'Solo el responsable asignado (usuario de sesion) puede culminar esta entrega',
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

    -- CON_OBSERVACION no bloquea: un arañazo o detalle leve queda en la
    -- bitacora y en el item, pero la entrega puede culminarse.

    -- ------------------------------------------------------------
    -- Cierre de custodia: EN_TRANSITO / PENDIENTE_ENVIO -> EN_PODER_CLIENTE
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

    IF v_id_en_poder IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontro el estado EN_PODER_CLIENTE en catalogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    IF v_id_transito IS NULL AND v_id_pend_envio IS NULL THEN
        RETURN json_build_object(
            'error', 'Faltan estados EN_TRANSITO / PENDIENTE_ENVIO en catalogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE ai.id_balon IS NOT NULL),
        COUNT(*) FILTER (
            WHERE ai.id_balon IS NOT NULL
              AND b.id_estado_balon IN (v_id_transito, v_id_pend_envio)
        )
    INTO v_cilindros_tot, v_cilindros_esp
    FROM age_actividad_item ai
    LEFT JOIN bal_balon b ON b.id = ai.id_balon AND b.estado = 1
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    -- Accesorios-only: sin cilindros no se exige custodia.
    IF v_cilindros_tot > 0 AND v_cilindros_esp = 0 THEN
        RETURN json_build_object(
            'error', 'Los cilindros no estan en EN_TRANSITO ni PENDIENTE_ENVIO; no se puede culminar la entrega',
            'registro', NULL
        );
    END IF;

    -- Custodia primero: si falla, la actividad no queda REALIZADA a medias.
    UPDATE bal_balon b
    SET id_estado_balon = v_id_en_poder,
        -- Un cilindro en poder del cliente sin cliente_ubicacion seria un
        -- estado roto; si la venta ya lo apunto, se respeta.
        id_cliente_ubicacion = COALESCE(b.id_cliente_ubicacion, v_act.id_cliente),
        id_almacen = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id
      AND ai.estado = 1
      AND ai.id_balon = b.id
      AND b.estado = 1
      AND b.id_estado_balon IN (v_id_transito, v_id_pend_envio);

    GET DIAGNOSTICS v_cilindros_upd = ROW_COUNT;

    IF v_cilindros_esp > 0 AND v_cilindros_upd = 0 THEN
        RETURN json_build_object(
            'error', format(
                'No se actualizo ningun cilindro a EN_PODER_CLIENTE (se esperaban %s)',
                v_cilindros_esp
            ),
            'registro', NULL
        );
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_realizada,
        fecha_hora_cierre = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;


-- Function: age_iniciar_recojo
-- Pone el recojo EN_RUTA. Exige responsable e ítems materializados.
-- La verificación (escaneo) se hace mientras se recoge; el cierre con
-- almacén destino es age_culminar_recojo.

DROP FUNCTION IF EXISTS age_iniciar_recojo(integer, integer);

CREATE OR REPLACE FUNCTION age_iniciar_recojo(
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
    v_items          INTEGER;
    v_id_trabajador_sesion INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_trabajador_responsable, a.id_usuario_responsable,
           a.id_estado_actividad, a.id_prestamo, a.id_alquiler
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

    IF COALESCE(v_nombre_tipo, '') <> 'RECOJO' THEN
        RETURN json_build_object('error', 'Solo las actividades de RECOJO tienen este flujo', 'registro', NULL);
    END IF;

    IF v_act.id_prestamo IS NULL AND v_act.id_alquiler IS NULL THEN
        RETURN json_build_object('error', 'El recojo no tiene prestamo ni alquiler de origen', 'registro', NULL);
    END IF;

    IF v_nombre_estado IN ('REALIZADA', 'CANCELADA', 'CANCELADO') THEN
        RETURN json_build_object('error', format('La actividad ya esta %s', v_nombre_estado), 'registro', NULL);
    END IF;

    IF v_nombre_estado = 'EN_RUTA' THEN
        RETURN json_build_object('error', 'El recojo ya esta en ruta', 'registro', NULL);
    END IF;

    IF v_act.id_trabajador_responsable IS NULL THEN
        RETURN json_build_object('error', 'Asigna un responsable antes de iniciar el recojo', 'registro', NULL);
    END IF;

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object(
            'error', 'Se requiere el usuario de sesion para iniciar el recojo',
            'registro', NULL
        );
    END IF;

    SELECT u.id_trabajador INTO v_id_trabajador_sesion
    FROM auth_usuarios u
    WHERE u.id = p_id_usuario_auditoria AND u.estado = TRUE;

    IF NOT (
        (v_act.id_trabajador_responsable IS NOT NULL AND v_id_trabajador_sesion IS NOT NULL
            AND v_id_trabajador_sesion = v_act.id_trabajador_responsable)
        OR (v_act.id_usuario_responsable IS NOT NULL AND p_id_usuario_auditoria = v_act.id_usuario_responsable)
    ) THEN
        RETURN json_build_object(
            'error', 'Solo el responsable asignado (usuario de sesion) puede iniciar este recojo',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_en_ruta
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(lo.nombre)) = 'EN_RUTA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_en_ruta IS NULL THEN
        RETURN json_build_object('error', 'No se encontro el estado EN_RUTA en EstadoActividad', 'registro', NULL);
    END IF;

    -- Materializa ítems si aún no están (préstamo/alquiler lazy).
    PERFORM age_iniciar_verificacion(p_id, p_id_usuario_auditoria);

    SELECT COUNT(*) INTO v_items
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    IF v_items = 0 THEN
        RETURN json_build_object(
            'error', 'El recojo no tiene cilindros/accesorios pendientes que recoger',
            'registro', NULL
        );
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_en_ruta,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- No se mueve custodia aquí: el cilindro sigue en poder del cliente hasta
    -- age_culminar_recojo, que llama a bal_devolver_* con el almacén destino.

    RETURN age_obtener_actividad(p_id);
END;
$function$;


-- Function: age_culminar_recojo
-- Cierra el recojo como REALIZADA tras verificar lo recogido y elige almacén
-- destino. Devuelve cada cilindro (préstamo/alquiler) al almacén indicado.

DROP FUNCTION IF EXISTS age_culminar_recojo(integer, integer, integer);

CREATE OR REPLACE FUNCTION age_culminar_recojo(
    p_id integer,
    p_id_almacen_destino integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_act            RECORD;
    v_nombre_estado  VARCHAR;
    v_nombre_tipo    VARCHAR;
    v_id_realizada   INTEGER;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_pendientes     INTEGER;
    v_item           RECORD;
    v_dev            JSON;
    v_devueltos      INTEGER := 0;
    v_esperados      INTEGER := 0;
    v_id_almacen_alq INTEGER;
    v_id_trabajador_sesion INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_estado_actividad, a.id_prestamo, a.id_alquiler, a.id_cliente,
           a.id_trabajador_responsable, a.id_usuario_responsable
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

    IF COALESCE(v_nombre_tipo, '') <> 'RECOJO' THEN
        RETURN json_build_object('error', 'Solo las actividades de RECOJO tienen este flujo', 'registro', NULL);
    END IF;

    IF COALESCE(v_nombre_estado, '') <> 'EN_RUTA' THEN
        RETURN json_build_object(
            'error', 'Solo se puede culminar un recojo que este EN_RUTA',
            'registro', NULL
        );
    END IF;

    IF v_act.id_trabajador_responsable IS NULL AND v_act.id_usuario_responsable IS NULL THEN
        RETURN json_build_object(
            'error', 'Asigna un responsable antes de culminar el recojo',
            'registro', NULL
        );
    END IF;

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object(
            'error', 'Se requiere el usuario de sesion para culminar el recojo',
            'registro', NULL
        );
    END IF;

    SELECT u.id_trabajador INTO v_id_trabajador_sesion
    FROM auth_usuarios u
    WHERE u.id = p_id_usuario_auditoria AND u.estado = TRUE;

    IF NOT (
        (v_act.id_trabajador_responsable IS NOT NULL AND v_id_trabajador_sesion IS NOT NULL
            AND v_id_trabajador_sesion = v_act.id_trabajador_responsable)
        OR (v_act.id_usuario_responsable IS NOT NULL AND p_id_usuario_auditoria = v_act.id_usuario_responsable)
    ) THEN
        RETURN json_build_object(
            'error', 'Solo el responsable asignado (usuario de sesion) puede culminar este recojo',
            'registro', NULL
        );
    END IF;

    IF p_id_almacen_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'Debes indicar el almacen destino donde ingresan los cilindros',
            'registro', NULL
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'El almacen destino no existe o esta inactivo',
            'registro', NULL
        );
    END IF;

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

    -- En recojo el momento de verificación operativa es LLEGADA (= recogido
    -- confirmado). Las observaciones leves no bloquean.
    SELECT COUNT(*) FILTER (
        WHERE ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_ok
          AND ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_observado
    )
    INTO v_pendientes
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    IF v_pendientes > 0 THEN
        RETURN json_build_object(
            'error', format(
                'Faltan %s item(s) por verificar en el recojo antes de culminar',
                v_pendientes
            ),
            'registro', NULL
        );
    END IF;

    SELECT COUNT(*) INTO v_esperados
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1
      AND (
            ai.id_prestamo_detalle IS NOT NULL
         OR ai.id_alquiler_detalle IS NOT NULL
         OR (ai.id_balon IS NULL AND ai.id_producto IS NOT NULL AND v_act.id_alquiler IS NOT NULL)
      );

    -- Devuelve cada cilindro al almacén elegido.
    -- Cualquier error de bal_devolver_* aborta con RAISE para revertir
    -- devoluciones parciales ya aplicadas en esta misma transacción.
    FOR v_item IN
        SELECT ai.id, ai.id_balon, ai.id_prestamo_detalle, ai.id_alquiler_detalle,
               ai.id_producto, ai.observacion_llegada
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id AND ai.estado = 1
        ORDER BY ai.item
    LOOP
        IF v_item.id_prestamo_detalle IS NOT NULL THEN
            v_dev := bal_devolver_prestamo_detalle(
                p_id                       => v_item.id_prestamo_detalle,
                p_fecha_devolucion         => CURRENT_DATE,
                p_id_almacen_destino       => p_id_almacen_destino,
                p_id_usuario_auditoria     => p_id_usuario_auditoria,
                p_nombre_estado_contenido  => 'VACIO',
                p_observacion              => COALESCE(v_item.observacion_llegada, 'Devolucion por actividad de recojo')
            );
            IF v_dev->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_dev->>'error';
            END IF;
            v_devueltos := v_devueltos + 1;

        ELSIF v_item.id_alquiler_detalle IS NOT NULL THEN
            v_dev := bal_devolver_alquiler_detalle(
                p_id                   => v_item.id_alquiler_detalle,
                p_fecha_devolucion     => CURRENT_DATE,
                p_id_almacen_destino   => p_id_almacen_destino,
                p_id_usuario_auditoria => p_id_usuario_auditoria
            );
            IF v_dev->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_dev->>'error';
            END IF;
            v_devueltos := v_devueltos + 1;

        ELSIF v_item.id_balon IS NULL
              AND v_item.id_producto IS NOT NULL
              AND v_act.id_alquiler IS NOT NULL THEN
            -- Accesorio/regulador materializado sin balón.
            -- bal_devolver_regulador_alquiler NO acepta p_id_almacen_destino:
            -- reingresa stock con bal_alquiler.id_almacen. Si es NULL, falla
            -- en claro en lugar de marcar REALIZADA sin reingreso.
            SELECT a.id_almacen INTO v_id_almacen_alq
            FROM bal_alquiler a
            WHERE a.id = v_act.id_alquiler AND a.estado = 1;

            IF v_id_almacen_alq IS NULL THEN
                RAISE EXCEPTION
                    'El alquiler no tiene id_almacen para reingresar el regulador; bal_devolver_regulador_alquiler no acepta almacen destino (defina id_almacen en el alquiler)';
            END IF;

            v_dev := bal_devolver_regulador_alquiler(
                p_id_alquiler          => v_act.id_alquiler,
                p_fecha                => CURRENT_DATE,
                p_condicion            => 'BUENO',
                p_observacion          => COALESCE(v_item.observacion_llegada, 'Devolucion por actividad de recojo'),
                p_id_recojo            => NULL,
                p_id_usuario_auditoria => p_id_usuario_auditoria
            );
            IF v_dev->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_dev->>'error';
            END IF;
            v_devueltos := v_devueltos + 1;
        END IF;
    END LOOP;

    IF v_esperados > 0 AND v_devueltos = 0 THEN
        RAISE EXCEPTION
            'No se devolvio ningun cilindro/accesorio pese a haber % item(s) por devolver; no se marca REALIZADA',
            v_esperados;
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_realizada,
        fecha_hora_cierre = NOW(),
        hora_fin_estimada = COALESCE(hora_fin_estimada, LOCALTIME),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
EXCEPTION
    WHEN OTHERS THEN
        -- Revierte devoluciones parciales del loop y expone el error al API.
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;


-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: age_cancelar_actividad
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.941Z
DROP FUNCTION IF EXISTS age_cancelar_actividad(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_cancelar_actividad(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_estado_cancelada INTEGER;
    v_id_estado_actual INTEGER;
    v_nombre_estado_actual VARCHAR;
    v_id_pend_envio INTEGER;
    v_id_transito INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT o.id INTO v_id_estado_cancelada
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(o.nombre)) = 'CANCELADA'
    LIMIT 1;

    IF v_id_estado_cancelada IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'No se encontró el estado CANCELADA en EstadoActividad.');
    END IF;

    SELECT a.id_estado_actividad, UPPER(TRIM(ea.nombre))
    INTO v_id_estado_actual, v_nombre_estado_actual
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_nombre_estado_actual IN ('CANCELADA', 'CANCELADO') THEN
        RETURN json_build_object('registro', NULL, 'error', 'La actividad ya se encuentra cancelada.');
    END IF;

    IF v_nombre_estado_actual = 'REALIZADA' THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'No se puede cancelar una actividad REALIZADA.'
        );
    END IF;

    UPDATE age_actividad
    SET
        id_estado_actividad = v_id_estado_cancelada,
        fecha_hora_cierre = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- ------------------------------------------------------------
    -- Camino de vuelta de la custodia: EN_TRANSITO -> PENDIENTE_ENVIO
    --
    -- Si se cancela un reparto que ya habia salido, los cilindros vuelven a
    -- estar comprometidos pero sin viaje en curso. Sin esto quedarian en
    -- transito para siempre, que es justo el atasco que ya sufrio
    -- PENDIENTE_ENVIO por no tener salida.
    --
    -- Se filtra por el estado actual del cilindro y no por el de la actividad:
    -- asi es idempotente y no toca cilindros que ya siguieron otro camino.
    -- ------------------------------------------------------------
    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_transito IS NOT NULL AND v_id_pend_envio IS NOT NULL THEN
        UPDATE bal_balon b
        SET id_estado_balon = v_id_pend_envio,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id
          AND ai.estado = 1
          AND ai.id_balon = b.id
          AND b.estado = 1
          AND b.id_estado_balon = v_id_transito;
    END IF;

    RETURN age_obtener_actividad(p_id);
END;
$function$;


-- Function: age_asignar_responsable_actividad
-- Source: migraciones/20260909_age_responsable_apoyo.sql

DROP FUNCTION IF EXISTS age_asignar_responsable_actividad(p_id integer, p_id_usuario_auditoria integer, p_id_trabajador_responsable integer);
DROP FUNCTION IF EXISTS age_asignar_responsable_actividad(integer, integer, integer, integer, boolean);

CREATE OR REPLACE FUNCTION age_asignar_responsable_actividad(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_id_trabajador_responsable integer DEFAULT NULL::integer,
    p_id_trabajador_apoyo integer DEFAULT NULL::integer,
    p_liberar boolean DEFAULT FALSE
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre_estado VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM age_actividad WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF COALESCE(p_liberar, FALSE) THEN
        SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_estado
        FROM age_actividad a
        LEFT JOIN gen_lista_opciones lo ON lo.id = a.id_estado_actividad
        WHERE a.id = p_id AND a.estado = 1;

        -- Liberar en ruta dejaria cilindros EN_TRANSITO sin responsable.
        IF COALESCE(v_nombre_estado, '') = 'EN_RUTA' THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', 'Cancela la actividad o culmina antes de liberar'
            );
        END IF;

        UPDATE age_actividad
        SET id_trabajador_responsable = NULL,
            id_trabajador_apoyo = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id AND estado = 1;

        RETURN age_obtener_actividad(p_id);
    END IF;

    -- Sin esto, "Tomar actividad" desde un usuario sin ficha de trabajador
    -- dejaba la actividad sin asignar y devolvia exito.
    IF p_id_trabajador_responsable IS NULL THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'No hay un trabajador que asignar: tu usuario no tiene ficha de trabajador vinculada.'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM tra_trabajadores t
        WHERE t.id = p_id_trabajador_responsable AND t.estado = 1
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El responsable debe ser un trabajador vigente.');
    END IF;

    IF p_id_trabajador_apoyo IS NOT NULL THEN
        IF p_id_trabajador_apoyo = p_id_trabajador_responsable THEN
            RETURN json_build_object('registro', NULL, 'error', 'El apoyo no puede ser la misma persona que el responsable.');
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM tra_trabajadores t
            WHERE t.id = p_id_trabajador_apoyo AND t.estado = 1
        ) THEN
            RETURN json_build_object('registro', NULL, 'error', 'El apoyo debe ser un trabajador vigente.');
        END IF;
    END IF;

    UPDATE age_actividad
    SET id_trabajador_responsable = p_id_trabajador_responsable,
        id_trabajador_apoyo = p_id_trabajador_apoyo,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;


-- Function: age_obtener_actividad
-- Synced from migracion 20260908_age_recojo_vencidos_fk.sql

CREATE OR REPLACE FUNCTION age_obtener_actividad(p_id integer)
RETURNS json
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
    v_items JSON;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_detalle_origen JSON := NULL;
    v_tiene_items BOOLEAN;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON)
    INTO v_items
    FROM (
        SELECT
            i.id,
            i.item,
            i.id_producto,
            COALESCE(p.nombre, i.descripcion) AS nombre_producto,
            i.descripcion,
            i.cantidad,
            um.nombre AS nombre_unidad_medida,
            i.id_balon,
            b.codigo_balon,
            b.numero_serie AS numero_serie_balon,
            tb.nombre AS nombre_tipo_balon,
            b.id_producto_gas,
            COALESCE(pgb.nombre, p.nombre) AS nombre_producto_gas,
            i.id_estado_verificacion_salida,
            evs.nombre AS estado_verificacion_salida,
            i.observacion_salida,
            i.id_estado_verificacion_llegada,
            evl.nombre AS estado_verificacion_llegada,
            i.observacion_llegada,
            i.id_estado_producto_recogido,
            epr.nombre AS estado_producto_recogido,
            i.id_doc_salida_detalle,
            i.id_venta_detalle,
            i.id_prestamo_detalle,
            i.id_alquiler_detalle
        FROM age_actividad_item i
        LEFT JOIN pro_producto p ON p.id = i.id_producto
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        LEFT JOIN bal_balon b ON b.id = i.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones evs ON evs.id = i.id_estado_verificacion_salida
        LEFT JOIN gen_lista_opciones evl ON evl.id = i.id_estado_verificacion_llegada
        LEFT JOIN gen_lista_opciones epr ON epr.id = i.id_estado_producto_recogido
        WHERE i.id_actividad = p_id AND i.estado = 1
    ) t;

    v_tiene_items := COALESCE(json_array_length(v_items), 0) > 0;

    SELECT act.id_prestamo, act.id_alquiler
    INTO v_id_prestamo, v_id_alquiler
    FROM age_actividad act
    WHERE act.id = p_id AND act.estado = 1;

    IF NOT v_tiene_items AND v_id_prestamo IS NOT NULL THEN
        SELECT json_build_object(
            'origen', 'PRESTAMO',
            'id_origen', p.id,
            'numero', p.numero_prestamo,
            'fecha_pactada', p.fecha_retorno_pactada,
            'cilindros', COALESCE((
                SELECT json_agg(row_to_json(c) ORDER BY c.id)
                FROM (
                    SELECT
                        pd.id,
                        pd.id_balon,
                        b.codigo_balon,
                        b.numero_serie AS numero_serie_balon,
                        tb.nombre AS nombre_tipo_balon,
                        COALESCE(pd.id_producto, b.id_producto_gas) AS id_producto,
                        COALESCE(pg.nombre, pgb.nombre) AS nombre_producto,
                        pgb.nombre AS nombre_producto_gas,
                        1::NUMERIC AS cantidad
                    FROM bal_prestamo_detalle pd
                    LEFT JOIN bal_balon b ON b.id = pd.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN pro_producto pg ON pg.id = pd.id_producto
                    LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
                    WHERE pd.id_prestamo = p.id
                      AND pd.estado = 1
                      AND pd.fecha_devolucion IS NULL
                      AND pd.id_balon IS NOT NULL
                ) c
            ), '[]'::JSON),
            'garantias', COALESCE((
                SELECT json_agg(row_to_json(g) ORDER BY g.id)
                FROM (
                    SELECT
                        vg.id,
                        vg.monto_saldo,
                        vg.monto_cobrado,
                        vg.monto_devuelto,
                        eg.nombre AS nombre_estado,
                        pr.nombre AS nombre_producto
                    FROM ven_garantia vg
                    LEFT JOIN gen_lista_opciones eg ON eg.id = vg.id_estado
                    LEFT JOIN pro_producto pr ON pr.id = vg.id_producto
                    WHERE vg.id_prestamo = p.id AND vg.estado = 1
                ) g
            ), '[]'::JSON)
        )
        INTO v_detalle_origen
        FROM bal_prestamo p
        WHERE p.id = v_id_prestamo;
    ELSIF NOT v_tiene_items AND v_id_alquiler IS NOT NULL THEN
        SELECT json_build_object(
            'origen', 'ALQUILER',
            'id_origen', a.id,
            'numero', a.numero_alquiler,
            'fecha_pactada', a.fecha_fin_pactada,
            'cilindros', COALESCE((
                SELECT json_agg(row_to_json(c) ORDER BY c.id)
                FROM (
                    SELECT
                        ad.id,
                        ad.id_balon,
                        b.codigo_balon,
                        b.numero_serie AS numero_serie_balon,
                        tb.nombre AS nombre_tipo_balon,
                        b.id_producto_gas AS id_producto,
                        pgb.nombre AS nombre_producto,
                        pgb.nombre AS nombre_producto_gas,
                        1::NUMERIC AS cantidad
                    FROM bal_alquiler_detalle ad
                    LEFT JOIN bal_balon b ON b.id = ad.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
                    WHERE ad.id_alquiler = a.id
                      AND ad.estado = 1
                      AND ad.fecha_devolucion IS NULL
                      AND ad.id_balon IS NOT NULL
                ) c
            ), '[]'::JSON),
            'garantias', COALESCE((
                SELECT json_agg(row_to_json(g) ORDER BY g.id)
                FROM (
                    SELECT
                        vg.id,
                        vg.monto_saldo,
                        vg.monto_cobrado,
                        vg.monto_devuelto,
                        eg.nombre AS nombre_estado,
                        pr.nombre AS nombre_producto
                    FROM ven_garantia vg
                    LEFT JOIN gen_lista_opciones eg ON eg.id = vg.id_estado
                    LEFT JOIN pro_producto pr ON pr.id = vg.id_producto
                    WHERE vg.id_alquiler = a.id AND vg.estado = 1
                ) g
            ), '[]'::JSON),
            'regulador', CASE
                WHEN a.id_producto_regulador IS NOT NULL AND a.fecha_devolucion_regulador IS NULL
                THEN json_build_object(
                    'id_producto', a.id_producto_regulador,
                    'nombre_producto', COALESCE(pr.nombre, ps.nombre),
                    'codigo_producto', COALESCE(pr.codigo, ps.codigo),
                    'pendiente', TRUE
                )
                ELSE NULL
            END
        )
        INTO v_detalle_origen
        FROM bal_alquiler a
        LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
        LEFT JOIN pro_producto ps ON ps.id = a.id_producto_stock
        WHERE a.id = v_id_alquiler;
    END IF;

    SELECT row_to_json(t)
    INTO v_registro
    FROM (
        SELECT
            act.id,
            act.titulo,
            act.descripcion,
            act.fecha_programada,
            act.hora_inicio_estimada,
            act.hora_fin_estimada,
            act.fecha_hora_cierre,
            act.id_tipo_actividad,
            ta.nombre AS nombre_tipo_actividad,
            act.id_prioridad,
            pr.nombre AS nombre_prioridad,
            act.id_cliente,
            c.razon_social AS razon_social_cliente,
            dir.latitud AS latitud_cliente,
            dir.longitud AS longitud_cliente,
            act.id_trabajador_responsable,
            TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)) AS nombre_trabajador_responsable,
            act.id_trabajador_apoyo,
            TRIM(CONCAT_WS(' ', ap.nombres, ap.apellido_paterno, ap.apellido_materno)) AS nombre_trabajador_apoyo,
            act.id_usuario_responsable,
            au.nombre AS nombre_usuario_responsable,
            act.id_chofer_responsable,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable,
            act.id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            act.id_doc_salida,
            ds.serie AS serie_doc_salida,
            ds.numero_sunat AS numero_sunat_doc_salida,
            ds.numero AS numero_doc_salida,
            act.id_prestamo,
            bp.numero_prestamo,
            bp.fecha_retorno_pactada AS fecha_retorno_pactada_prestamo,
            act.id_alquiler,
            ba.numero_alquiler,
            ba.fecha_fin_pactada AS fecha_fin_pactada_alquiler,
            act.id_tipo_origen,
            tor.nombre AS nombre_tipo_origen,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.observaciones,
            act.estado,
            act.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            act.id_usuario_modificacion,
            umod.nombre AS nombre_usuario_modificacion,
            act.fecha_creacion,
            act.fecha_modificacion,
            v_items AS items,
            v_detalle_origen AS detalle_origen
        FROM age_actividad act
        LEFT JOIN gen_lista_opciones ta
            ON ta.id = act.id_tipo_actividad
           AND ta.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'TipoActividad' OR gl.id = 48)
        LEFT JOIN gen_lista_opciones pr
            ON pr.id = act.id_prioridad
           AND pr.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'PrioridadActividad' OR gl.id = 50)
        LEFT JOIN gen_lista_opciones ea
            ON ea.id = act.id_estado_actividad
           AND ea.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'EstadoActividad' OR gl.id = 49)
        LEFT JOIN gen_lista_opciones tor ON tor.id = act.id_tipo_origen
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN LATERAL (
            SELECT cd.latitud, cd.longitud
            FROM cli_direcciones cd
            WHERE cd.id_cliente = act.id_cliente AND cd.estado = 1
            ORDER BY cd.es_principal DESC NULLS LAST, cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        LEFT JOIN tra_trabajadores tr ON tr.id = act.id_trabajador_responsable
        LEFT JOIN tra_trabajadores ap ON ap.id = act.id_trabajador_apoyo
        LEFT JOIN auth_usuarios au ON au.id_trabajador = tr.id AND au.estado = TRUE
        LEFT JOIN gen_chofer ch ON ch.id_trabajador = tr.id AND ch.estado = 1
        LEFT JOIN ven_comprobante vc ON act.id_comprobante = vc.id
        LEFT JOIN doc_salida ds ON act.id_doc_salida = ds.id
        LEFT JOIN bal_prestamo bp ON bp.id = act.id_prestamo
        LEFT JOIN bal_alquiler ba ON ba.id = act.id_alquiler
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios umod ON act.id_usuario_modificacion = umod.id
        WHERE act.id = p_id AND act.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

