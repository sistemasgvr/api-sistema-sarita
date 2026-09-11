-- Function: age_culminar_entrega
-- Source: migraciones/20260909_age_culminar_entrega_custodia.sql
--
-- Actualizada por database_sql/migraciones/20260910_age_custodia_recojo_candado.sql:
--   · se exige el juego COMPLETO de cilindros en custodia, igual que
--     age_iniciar_entrega. Con "al menos uno" bastaba un cilindro en tránsito
--     para cerrar la entrega y los demás quedaban colgados en su estado previo;
--   · el descuadre posterior al UPDATE es RAISE (rollback), no error soft.

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
    -- Con cilindros se exige que TODOS esten en custodia (no "al menos uno"):
    -- cerrar con un subconjunto dejaba al resto fuera de EN_PODER_CLIENTE.
    IF v_cilindros_tot > 0 AND v_cilindros_esp < v_cilindros_tot THEN
        RETURN json_build_object(
            'error', format(
                'Faltan %s cilindro(s) en EN_TRANSITO o PENDIENTE_ENVIO para culminar la entrega (hay %s de %s)',
                v_cilindros_tot - v_cilindros_esp,
                v_cilindros_esp,
                v_cilindros_tot
            ),
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

    -- El UPDATE ya corrió: un error soft aquí confirmaría los cilindros que sí
    -- cambiaron y dejaría la entrega cerrada a medias.
    IF v_cilindros_esp > 0 AND v_cilindros_upd <> v_cilindros_esp THEN
        RAISE EXCEPTION
            'No se actualizaron todos los cilindros a EN_PODER_CLIENTE (se esperaban %, se actualizaron %)',
            v_cilindros_esp, v_cilindros_upd;
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
