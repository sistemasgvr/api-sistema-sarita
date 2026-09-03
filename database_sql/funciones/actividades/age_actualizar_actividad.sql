-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: age_actualizar_actividad
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.941Z
DROP FUNCTION IF EXISTS age_actualizar_actividad(p_id integer, p_titulo character varying, p_descripcion text, p_fecha_programada date, p_hora_inicio_estimada time without time zone, p_hora_fin_estimada time without time zone, p_fecha_hora_cierre timestamp without time zone, p_id_tipo_actividad integer, p_id_prioridad integer, p_id_cliente integer, p_id_trabajador_responsable integer, p_id_estado_actividad integer, p_observaciones character varying, p_id_usuario_auditoria integer, p_id_comprobante integer, p_id_guia_remision integer, p_items json);

CREATE OR REPLACE FUNCTION age_actualizar_actividad(p_id integer, p_titulo character varying, p_descripcion text, p_fecha_programada date, p_hora_inicio_estimada time without time zone, p_hora_fin_estimada time without time zone, p_fecha_hora_cierre timestamp without time zone, p_id_tipo_actividad integer, p_id_prioridad integer, p_id_cliente integer DEFAULT NULL::integer, p_id_trabajador_responsable integer DEFAULT NULL::integer, p_id_estado_actividad integer DEFAULT NULL::integer, p_observaciones character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_comprobante integer DEFAULT NULL::integer, p_id_guia_remision integer DEFAULT NULL::integer, p_items json DEFAULT NULL::json)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_tipo VARCHAR;
    v_item JSON;
    v_n INTEGER := 0;
    v_hora_inicio TIME;
    v_hora_fin TIME;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM age_actividad WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    SELECT
        COALESCE(p_hora_inicio_estimada, hora_inicio_estimada),
        COALESCE(p_hora_fin_estimada, hora_fin_estimada)
    INTO v_hora_inicio, v_hora_fin
    FROM age_actividad
    WHERE id = p_id AND estado = 1;

    IF v_hora_inicio IS NOT NULL AND v_hora_fin IS NOT NULL THEN
        IF v_hora_inicio >= v_hora_fin THEN
            RETURN json_build_object('registro', NULL, 'error', 'La hora de inicio estimada debe ser menor a la hora de fin estimada.');
        END IF;
    END IF;

    IF p_id_tipo_actividad IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_tipo_actividad
          AND o.estado = 1
          AND (l.nombre = 'TipoActividad' OR l.id = 48)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El tipo de actividad indicado no es válido.');
    END IF;

    IF p_id_prioridad IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_prioridad
          AND o.estado = 1
          AND (l.nombre = 'PrioridadActividad' OR l.id = 50)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'La prioridad indicada no es válida.');
    END IF;

    IF p_id_estado_actividad IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_estado_actividad
          AND o.estado = 1
          AND (l.nombre = 'EstadoActividad' OR l.id = 49)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El estado de actividad indicado no es válido.');
    END IF;

    IF p_id_tipo_actividad IS NOT NULL THEN
        SELECT UPPER(TRIM(nombre)) INTO v_tipo
        FROM gen_lista_opciones
        WHERE id = p_id_tipo_actividad;

        IF v_tipo = 'REPARTO' THEN
            IF p_id_trabajador_responsable IS NOT NULL THEN
                IF NOT EXISTS (
                    SELECT 1 FROM tra_trabajadores t
                    INNER JOIN gen_chofer c ON c.id_trabajador = t.id
                    WHERE t.id = p_id_trabajador_responsable AND t.estado = 1 AND c.estado = 1 AND c.id_cliente IS NULL
                ) THEN
                    RETURN json_build_object('registro', NULL, 'error', 'El responsable debe ser un trabajador chofer de flota propia (repartidor).');
                END IF;
            END IF;
        END IF;
    END IF;

    IF p_id_trabajador_responsable IS NOT NULL AND p_hora_inicio_estimada IS NOT NULL AND p_hora_fin_estimada IS NOT NULL THEN
        IF EXISTS (
            SELECT 1
            FROM age_actividad
            WHERE id <> p_id
              AND id_trabajador_responsable = p_id_trabajador_responsable
              AND fecha_programada = p_fecha_programada
              AND estado = 1
              AND NOT EXISTS (
                  SELECT 1 FROM gen_lista_opciones ea
                  WHERE ea.id = age_actividad.id_estado_actividad
                    AND UPPER(TRIM(ea.nombre)) IN ('CANCELADA', 'CANCELADO')
              )
              AND (
                  (p_hora_inicio_estimada >= hora_inicio_estimada AND p_hora_inicio_estimada < hora_fin_estimada)
                  OR (p_hora_fin_estimada > hora_inicio_estimada AND p_hora_fin_estimada <= hora_fin_estimada)
                  OR (p_hora_inicio_estimada <= hora_inicio_estimada AND p_hora_fin_estimada >= hora_fin_estimada)
              )
        ) THEN
            RETURN json_build_object('registro', NULL, 'error', 'El responsable (trabajador) ya tiene otra actividad asignada que se cruza en ese horario para la fecha seleccionada.');
        END IF;
    END IF;

    UPDATE age_actividad
    SET
        titulo = COALESCE(p_titulo, titulo),
        descripcion = COALESCE(p_descripcion, descripcion),
        fecha_programada = COALESCE(p_fecha_programada, fecha_programada),
        hora_inicio_estimada = COALESCE(p_hora_inicio_estimada, hora_inicio_estimada),
        hora_fin_estimada = COALESCE(p_hora_fin_estimada, hora_fin_estimada),
        fecha_hora_cierre = COALESCE(p_fecha_hora_cierre, fecha_hora_cierre),
        id_tipo_actividad = COALESCE(p_id_tipo_actividad, id_tipo_actividad),
        id_prioridad = COALESCE(p_id_prioridad, id_prioridad),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_trabajador_responsable = COALESCE(p_id_trabajador_responsable, id_trabajador_responsable),
        id_comprobante = COALESCE(p_id_comprobante, id_comprobante),
        id_guia_remision = COALESCE(p_id_guia_remision, id_guia_remision),
        id_estado_actividad = COALESCE(p_id_estado_actividad, id_estado_actividad),
        observaciones = COALESCE(p_observaciones, observaciones),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF p_items IS NOT NULL AND json_typeof(p_items) = 'array' THEN
        UPDATE age_actividad_item
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_actividad = p_id AND estado = 1;

        FOR v_item IN SELECT value FROM json_array_elements(p_items)
        LOOP
            v_n := v_n + 1;
            INSERT INTO age_actividad_item (
                id_actividad, item, id_producto, descripcion, cantidad, id_balon,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                p_id,
                COALESCE((v_item->>'item')::INTEGER, v_n),
                COALESCE((v_item->>'idProducto')::INTEGER, (v_item->>'id_producto')::INTEGER),
                NULLIF(TRIM(COALESCE(v_item->>'descripcion', '')), ''),
                COALESCE((v_item->>'cantidad')::NUMERIC, 1),
                COALESCE((v_item->>'idBalon')::INTEGER, (v_item->>'id_balon')::INTEGER),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    RETURN age_obtener_actividad(p_id);
END;
$function$;
