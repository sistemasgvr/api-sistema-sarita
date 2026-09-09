-- ============================================================
-- Migracion: flujo operativo RECOJO (iniciar -> verificar -> culminar)
-- Fecha: 2026-09-09
--
-- Flujo:
--   tomar/asignar -> Iniciar recojo (EN_RUTA + materializa items)
--                -> Verificar LLEGADA (escaneo de recogido)
--                -> Culminar recojo + id_almacen_destino
--                   (bal_devolver_* -> cilindros DISPONIBLE en almacen)
--
-- age_cambiar_estado_actividad_realizada rechaza REPARTO y RECOJO
-- (deben usar Culminar entrega / Culminar recojo).
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260909_age_flujo_recojo.sql
-- ============================================================
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
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_trabajador_responsable, a.id_estado_actividad,
           a.id_prestamo, a.id_alquiler
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
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_estado_actividad, a.id_prestamo, a.id_alquiler, a.id_cliente
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

    -- Devuelve cada cilindro al almacén elegido.
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
                RETURN json_build_object('error', v_dev->>'error', 'registro', NULL);
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
                RETURN json_build_object('error', v_dev->>'error', 'registro', NULL);
            END IF;
            v_devueltos := v_devueltos + 1;

        ELSIF v_item.id_balon IS NULL
              AND v_item.id_producto IS NOT NULL
              AND v_act.id_alquiler IS NOT NULL THEN
            -- Accesorio/regulador materializado sin balón.
            v_dev := bal_devolver_regulador_alquiler(
                p_id_alquiler          => v_act.id_alquiler,
                p_fecha                => CURRENT_DATE,
                p_condicion            => 'BUENO',
                p_observacion          => COALESCE(v_item.observacion_llegada, 'Devolucion por actividad de recojo'),
                p_id_recojo            => NULL,
                p_id_usuario_auditoria => p_id_usuario_auditoria
            );
            IF v_dev->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_dev->>'error', 'registro', NULL);
            END IF;
            v_devueltos := v_devueltos + 1;
        END IF;
    END LOOP;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_realizada,
        fecha_hora_cierre = NOW(),
        hora_fin_estimada = COALESCE(hora_fin_estimada, LOCALTIME),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;


-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: age_cambiar_estado_actividad_realizada
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.941Z
DROP FUNCTION IF EXISTS age_cambiar_estado_actividad_realizada(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_cambiar_estado_actividad_realizada(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_estado_realizada INTEGER;
    v_id_estado_actual INTEGER;
    v_nombre_tipo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_id_estado_realizada
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(lo.nombre)) = 'REALIZADA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_realizada IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'No se encontró el estado REALIZADA en EstadoActividad.');
    END IF;

    SELECT a.id_estado_actividad, UPPER(TRIM(t.nombre))
    INTO v_id_estado_actual, v_nombre_tipo
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones t ON t.id = a.id_tipo_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF COALESCE(v_nombre_tipo, '') = 'REPARTO' THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'El reparto se cierra con Culminar entrega, no marcando realizada a mano.'
        );
    END IF;

    IF COALESCE(v_nombre_tipo, '') = 'RECOJO' THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'El recojo se cierra con Culminar recojo (elige almacén destino), no marcando realizada a mano.'
        );
    END IF;

    IF v_id_estado_actual = v_id_estado_realizada THEN
        RETURN json_build_object('registro', NULL, 'error', 'La actividad ya se encuentra marcada como realizada.');
    END IF;

    UPDATE age_actividad
    SET 
        id_estado_actividad = v_id_estado_realizada,
        fecha_hora_cierre = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;
