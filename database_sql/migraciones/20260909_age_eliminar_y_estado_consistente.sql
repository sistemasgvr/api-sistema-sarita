-- ============================================================
-- Migracion: consistencia custodia al eliminar / editar actividad
-- Fecha: 2026-09-09
--
-- Problemas:
--   1. age_eliminar_actividad hacia baja logica sin revertir
--      EN_TRANSITO -> PENDIENTE_ENVIO. Un reparto eliminado despues de
--      iniciar entrega dejaba cilindros en transito sin viaje.
--   2. age_actualizar_actividad aceptaba cualquier id_estado_actividad,
--      asi que el formulario podia pasar EN_RUTA a PENDIENTE y romper
--      la misma consistencia.
--
-- Solucion:
--   * Eliminar replica el camino de vuelta de cancelar (solo cilindros
--     que siguen EN_TRANSITO).
--   * Actualizar rechaza cambios hacia/desde estados operativos
--     (EN_RUTA, REALIZADA, CANCELADA). Esos van por las acciones
--     dedicadas del flujo de entrega.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260909_age_eliminar_y_estado_consistente.sql
-- ============================================================

-- ------------------------------------------------------------
-- age_eliminar_actividad
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS age_eliminar_actividad(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_eliminar_actividad(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_transito   INTEGER;
    v_id_pend_envio INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE age_actividad
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Camino de vuelta de la custodia: EN_TRANSITO -> PENDIENTE_ENVIO
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

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;

-- ------------------------------------------------------------
-- age_actualizar_actividad
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS age_actualizar_actividad(p_id integer, p_titulo character varying, p_descripcion text, p_fecha_programada date, p_hora_inicio_estimada time without time zone, p_hora_fin_estimada time without time zone, p_fecha_hora_cierre timestamp without time zone, p_id_tipo_actividad integer, p_id_prioridad integer, p_id_cliente integer, p_id_trabajador_responsable integer, p_id_estado_actividad integer, p_observaciones character varying, p_id_usuario_auditoria integer, p_id_comprobante integer, p_id_guia_remision integer, p_items json);
DROP FUNCTION IF EXISTS age_actualizar_actividad(p_id integer, p_titulo character varying, p_descripcion text, p_fecha_programada date, p_hora_inicio_estimada time without time zone, p_hora_fin_estimada time without time zone, p_fecha_hora_cierre timestamp without time zone, p_id_tipo_actividad integer, p_id_prioridad integer, p_id_cliente integer, p_id_trabajador_responsable integer, p_id_estado_actividad integer, p_observaciones character varying, p_id_usuario_auditoria integer, p_id_comprobante integer, p_id_doc_salida integer, p_items json);

CREATE OR REPLACE FUNCTION age_actualizar_actividad(
    p_id integer,
    p_titulo character varying,
    p_descripcion text,
    p_fecha_programada date,
    p_hora_inicio_estimada time without time zone,
    p_hora_fin_estimada time without time zone,
    p_fecha_hora_cierre timestamp without time zone,
    p_id_tipo_actividad integer,
    p_id_prioridad integer,
    p_id_cliente integer DEFAULT NULL::integer,
    p_id_trabajador_responsable integer DEFAULT NULL::integer,
    p_id_estado_actividad integer DEFAULT NULL::integer,
    p_observaciones character varying DEFAULT NULL::character varying,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_id_comprobante integer DEFAULT NULL::integer,
    p_id_doc_salida integer DEFAULT NULL::integer,
    p_items json DEFAULT NULL::json
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_tipo VARCHAR;
    v_item JSON;
    v_n INTEGER := 0;
    v_hora_inicio TIME;
    v_hora_fin TIME;
    v_id_estado_actual INTEGER;
    v_nombre_estado_actual VARCHAR;
    v_nombre_estado_nuevo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id_estado_actividad, UPPER(TRIM(ea.nombre))
    INTO v_id_estado_actual, v_nombre_estado_actual
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    -- El formulario no mueve el flujo operativo.
    IF p_id_estado_actividad IS NOT NULL
       AND p_id_estado_actividad IS DISTINCT FROM v_id_estado_actual THEN

        SELECT UPPER(TRIM(nombre)) INTO v_nombre_estado_nuevo
        FROM gen_lista_opciones
        WHERE id = p_id_estado_actividad;

        IF COALESCE(v_nombre_estado_actual, '') IN (
            'EN_RUTA', 'REALIZADA', 'CANCELADA', 'CANCELADO'
        ) THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', format(
                    'No se puede cambiar el estado desde %s en la edicion. Usa las acciones de entrega (iniciar, culminar, cancelar).',
                    v_nombre_estado_actual
                )
            );
        END IF;

        IF COALESCE(v_nombre_estado_nuevo, '') IN (
            'EN_RUTA', 'REALIZADA', 'CANCELADA', 'CANCELADO'
        ) THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', format(
                    'El estado %s no se asigna desde el formulario. Usa las acciones de entrega (iniciar, culminar, cancelar).',
                    v_nombre_estado_nuevo
                )
            );
        END IF;
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

    IF p_id_doc_salida IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM doc_salida WHERE id = p_id_doc_salida AND estado = 1
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'La orden de salida indicada no existe.');
    END IF;

    IF p_id_tipo_actividad IS NOT NULL THEN
        SELECT UPPER(TRIM(nombre)) INTO v_tipo
        FROM gen_lista_opciones
        WHERE id = p_id_tipo_actividad;
    END IF;

    IF p_id_trabajador_responsable IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM tra_trabajadores t
            WHERE t.id = p_id_trabajador_responsable AND t.estado = 1
        ) THEN
            RETURN json_build_object('error', 'El responsable debe ser un trabajador vigente.');
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
        id_doc_salida = COALESCE(p_id_doc_salida, id_doc_salida),
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
