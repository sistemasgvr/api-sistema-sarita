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
