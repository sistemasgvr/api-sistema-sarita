-- Function: age_culminar_recojo
-- Cierra el recojo como REALIZADA tras verificar lo recogido y elige almacén
-- destino. Devuelve cada cilindro del préstamo al almacén indicado y, en un
-- recojo de alquiler, reingresa el regulador/accesorio.
--
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- el alquiler ya no tiene detalle de cilindros (bal_alquiler_detalle eliminada);
-- el ítem de alquiler es siempre el regulador (sin balón).

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
         OR (ai.id_balon IS NULL AND ai.id_producto IS NOT NULL AND v_act.id_alquiler IS NOT NULL)
      );

    -- Devuelve cada cilindro al almacén elegido.
    -- Cualquier error de bal_devolver_* aborta con RAISE para revertir
    -- devoluciones parciales ya aplicadas en esta misma transacción.
    FOR v_item IN
        SELECT ai.id, ai.id_balon, ai.id_prestamo_detalle,
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

        ELSIF v_item.id_balon IS NULL
              AND v_item.id_producto IS NOT NULL
              AND v_act.id_alquiler IS NOT NULL THEN
            -- Regulador/accesorio del alquiler (ítem sin balón).
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
