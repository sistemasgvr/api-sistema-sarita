-- Pone una entrega EN_RUTA y pasa sus cilindros a tránsito
DROP FUNCTION IF EXISTS public.age_iniciar_entrega (p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.age_iniciar_entrega (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
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

    IF v_cilindros_tot > 0 AND v_cilindros_esp < v_cilindros_tot THEN
        RETURN json_build_object(
            'error', format(
                'Faltan %s cilindro(s) en PENDIENTE_ENVIO para iniciar la entrega (hay %s de %s)',
                v_cilindros_tot - v_cilindros_esp,
                v_cilindros_esp,
                v_cilindros_tot
            ),
            'registro', NULL
        );
    END IF;

    UPDATE bal_balon b
    SET id_estado_balon = v_id_transito,
        id_almacen = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id
      AND ai.estado = 1
      AND ai.id_balon = b.id
      AND b.estado = 1
      AND b.id_estado_balon = v_id_pend_envio;

    GET DIAGNOSTICS v_cilindros_upd = ROW_COUNT;

    IF v_cilindros_esp > 0 AND v_cilindros_upd <> v_cilindros_esp THEN
        RAISE EXCEPTION
            'No se actualizaron todos los cilindros a EN_TRANSITO (se esperaban %, se actualizaron %)',
            v_cilindros_esp, v_cilindros_upd;
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_en_ruta,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;
