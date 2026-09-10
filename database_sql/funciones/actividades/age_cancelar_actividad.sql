-- Function: age_cancelar_actividad
--
-- Cancela la actividad. Para REPARTO, el camino de vuelta de custodia es
-- EN_TRANSITO → PENDIENTE_ENVIO (NO DISPONIBLE): la OS sigue vigente y sigue
-- dueña de la reserva; cancelar el viaje no libera el cilindro al stock
-- vendible. La liberación a DISPONIBLE ocurre al anular la OS
-- (doc_anular_salida).
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
    v_id_almacen_os INTEGER;
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
    -- IMPORTANTE: cancelar REPARTO NO pone DISPONIBLE. Si la OS sigue activa,
    -- los balones de sus items (via id_doc_salida / id_balon) permanecen en
    -- PENDIENTE_ENVIO: la orden sigue dueña de la reserva. Solo
    -- doc_anular_salida libera a DISPONIBLE.
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

    SELECT ds.id_almacen INTO v_id_almacen_os
    FROM age_actividad a
    JOIN doc_salida ds ON ds.id = a.id_doc_salida AND ds.estado = 1
    WHERE a.id = p_id;

    IF v_id_transito IS NOT NULL AND v_id_pend_envio IS NOT NULL THEN
        UPDATE bal_balon b
        SET id_estado_balon = v_id_pend_envio,
            -- age_iniciar_entrega deja id_almacen NULL al subir al camion;
            -- al cancelar, el cilindro vuelve al almacen de la OS si se conoce.
            id_almacen = COALESCE(v_id_almacen_os, b.id_almacen),
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
