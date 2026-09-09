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
