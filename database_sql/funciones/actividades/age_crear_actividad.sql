-- Function: age_crear_actividad
-- Source: migraciones/20260908_age_id_doc_salida_y_ordenes_disponibles.sql

DROP FUNCTION IF EXISTS age_crear_actividad(p_titulo character varying, p_descripcion text, p_fecha_programada date, p_hora_inicio_estimada time without time zone, p_hora_fin_estimada time without time zone, p_id_tipo_actividad integer, p_id_prioridad integer, p_id_cliente integer, p_id_trabajador_responsable integer, p_id_estado_actividad integer, p_observaciones character varying, p_id_usuario_auditoria integer, p_id_comprobante integer, p_id_guia_remision integer, p_items json);

CREATE OR REPLACE FUNCTION age_crear_actividad(
    p_titulo character varying,
    p_descripcion text,
    p_fecha_programada date,
    p_hora_inicio_estimada time without time zone,
    p_hora_fin_estimada time without time zone,
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
    v_id_verif_pendiente INTEGER;
    v_id_tipo_origen INTEGER;
    v_id INTEGER;
    v_tipo VARCHAR;
    v_cliente INTEGER;
    v_destinatario INTEGER;
    v_titulo VARCHAR;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_ciclo_os VARCHAR;
    v_item JSON;
    v_n INTEGER := 0;
BEGIN
    SELECT lo.id INTO v_id_verif_pendiente
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_origen
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoOrigenActividad' AND lo.nombre = 'ORDEN_SALIDA' AND lo.estado = 1
    LIMIT 1;

    SET TIME ZONE 'America/Lima';

    v_cliente := p_id_cliente;
    v_titulo := NULLIF(TRIM(COALESCE(p_titulo, '')), '');

    IF p_id_comprobante IS NOT NULL THEN
        SELECT vc.id_cliente, vc.serie, vc.numero
        INTO v_cliente, v_serie, v_numero
        FROM ven_comprobante vc
        WHERE vc.id = p_id_comprobante AND vc.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('registro', NULL, 'error', 'El comprobante indicado no existe.');
        END IF;

        v_cliente := COALESCE(p_id_cliente, v_cliente);
        IF v_titulo IS NULL THEN
            v_titulo := TRIM(CONCAT('Reparto ', COALESCE(v_serie, ''), '-', COALESCE(v_numero, '')));
        END IF;

        IF EXISTS (
            SELECT 1
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            WHERE a.id_comprobante = p_id_comprobante
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
        ) THEN
            RETURN json_build_object('registro', NULL, 'error', 'Este comprobante ya tiene un reparto / actividad vigente.');
        END IF;
    END IF;

    IF p_id_doc_salida IS NOT NULL THEN
        SELECT ds.id_cliente, ds.id_destinatario, ds.serie, ds.numero,
               UPPER(TRIM(ec.nombre))
        INTO v_cliente, v_destinatario, v_serie, v_numero, v_ciclo_os
        FROM doc_salida ds
        LEFT JOIN gen_lista_opciones ec ON ec.id = ds.id_estado_ciclo
        WHERE ds.id = p_id_doc_salida AND ds.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('registro', NULL, 'error', 'La orden de salida indicada no existe.');
        END IF;

        -- REPARTO no se puede crear sobre una OS ya anulada.
        IF v_ciclo_os = 'ANULADA' THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', 'No se puede crear un reparto sobre una orden de salida ANULADA.'
            );
        END IF;

        v_cliente := COALESCE(p_id_cliente, v_cliente, v_destinatario);
        IF v_titulo IS NULL THEN
            v_titulo := CASE
                WHEN NULLIF(TRIM(COALESCE(v_serie, '')), '') IS NOT NULL
                THEN CONCAT('Reparto ', TRIM(v_serie), '-', COALESCE(v_numero, ''))
                ELSE CONCAT('Reparto ', COALESCE(v_numero, ''))
            END;
        END IF;

        IF EXISTS (
            SELECT 1
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            WHERE a.id_doc_salida = p_id_doc_salida
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
        ) THEN
            RETURN json_build_object('registro', NULL, 'error', 'Esta orden de salida ya tiene un reparto / actividad vigente.');
        END IF;
    END IF;

    IF v_titulo IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'El tÃ­tulo es obligatorio.');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_tipo_actividad
          AND o.estado = 1
          AND (l.nombre = 'TipoActividad' OR l.id = 48)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El tipo de actividad indicado no es vÃ¡lido.');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_prioridad
          AND o.estado = 1
          AND (l.nombre = 'PrioridadActividad' OR l.id = 50)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'La prioridad indicada no es vÃ¡lida.');
    END IF;

    IF p_id_estado_actividad IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_estado_actividad
          AND o.estado = 1
          AND (l.nombre = 'EstadoActividad' OR l.id = 49)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El estado de actividad indicado no es vÃ¡lido.');
    END IF;

    IF p_hora_inicio_estimada IS NOT NULL AND p_hora_fin_estimada IS NOT NULL THEN
        IF p_hora_inicio_estimada >= p_hora_fin_estimada THEN
            RETURN json_build_object('registro', NULL, 'error', 'La hora de inicio estimada debe ser menor a la hora de fin estimada.');
        END IF;
    END IF;

    SELECT UPPER(TRIM(nombre)) INTO v_tipo
    FROM gen_lista_opciones
    WHERE id = p_id_tipo_actividad;

    -- El responsable de un reparto ya no tiene que ser chofer de flota propia:
    -- en la entrega suelen ir el chofer y alguien de apoyo (hay que subir los
    -- balones a un tercer o cuarto piso), y cualquiera de los dos puede figurar
    -- como responsable. Solo se exige que sea un trabajador vigente.
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
            WHERE id_trabajador_responsable = p_id_trabajador_responsable
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
            RETURN json_build_object('error', 'El responsable (trabajador) ya tiene otra actividad asignada que se cruza en ese horario para la fecha seleccionada.');
        END IF;
    END IF;

    INSERT INTO age_actividad (
        titulo, descripcion, fecha_programada,
        hora_inicio_estimada, hora_fin_estimada,
        id_tipo_actividad, id_prioridad, id_cliente,
        id_trabajador_responsable, id_comprobante,
        id_doc_salida, id_tipo_origen,
        id_estado_actividad, observaciones,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        v_titulo, p_descripcion, p_fecha_programada,
        p_hora_inicio_estimada, p_hora_fin_estimada,
        p_id_tipo_actividad, p_id_prioridad, v_cliente,
        p_id_trabajador_responsable, p_id_comprobante,
        p_id_doc_salida,
        CASE WHEN p_id_doc_salida IS NOT NULL THEN v_id_tipo_origen ELSE NULL END,
        p_id_estado_actividad, p_observaciones,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    IF p_items IS NOT NULL AND json_typeof(p_items) = 'array' THEN
        FOR v_item IN SELECT value FROM json_array_elements(p_items)
        LOOP
            v_n := v_n + 1;
            INSERT INTO age_actividad_item (
                id_actividad, item, id_producto, descripcion, cantidad, id_balon,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                v_id,
                COALESCE((v_item->>'item')::INTEGER, v_n),
                COALESCE((v_item->>'idProducto')::INTEGER, (v_item->>'id_producto')::INTEGER),
                NULLIF(TRIM(COALESCE(v_item->>'descripcion', '')), ''),
                COALESCE((v_item->>'cantidad')::NUMERIC, 1),
                COALESCE((v_item->>'idBalon')::INTEGER, (v_item->>'id_balon')::INTEGER),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    ELSIF p_id_comprobante IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            v_id,
            d.item,
            d.id_producto,
            NULLIF(TRIM(COALESCE(d.descripcion, '')), ''),
            d.cantidad,
            d.id_balon,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM ven_comprobante_detalle d
        WHERE d.id_comprobante = p_id_comprobante AND d.estado = 1
        ORDER BY d.item;
    ELSIF p_id_doc_salida IS NOT NULL THEN
        -- Detalle vÃ­a doc_obtener_salida (venta/prÃ©stamo/propio); no re-teclear.
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_doc_salida_detalle,
            id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            v_id,
            (d->>'item')::INTEGER,
            NULLIF(d->>'id_producto', '')::INTEGER,
            NULLIF(TRIM(COALESCE(d->>'descripcion', d->>'glosa', '')), ''),
            COALESCE((d->>'cantidad')::NUMERIC, 1),
            NULLIF(d->>'id_balon', '')::INTEGER,
            CASE WHEN COALESCE(d->>'origen_detalle', '') = 'PROPIO'
                 THEN NULLIF(d->>'id', '')::INTEGER END,
            v_id_verif_pendiente,
            v_id_verif_pendiente,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM json_array_elements(
            COALESCE(doc_obtener_salida(p_id_doc_salida)->'registro'->'detalle', '[]'::JSON)
        ) AS d
        ORDER BY (d->>'item')::INTEGER;
    END IF;

    RETURN age_obtener_actividad(v_id);
END;
$function$;

-- =============================================================================

