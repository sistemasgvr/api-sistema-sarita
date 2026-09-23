BEGIN;

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
    p_items json DEFAULT NULL::json,
    p_id_chofer_responsable integer DEFAULT NULL
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

    IF p_id_chofer_responsable IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_chofer WHERE id = p_id_chofer_responsable AND estado = 1
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El chofer seleccionado debe estar activo.');
    END IF;

    INSERT INTO age_actividad (
        titulo, descripcion, fecha_programada,
        hora_inicio_estimada, hora_fin_estimada,
        id_tipo_actividad, id_prioridad, id_cliente,
        id_trabajador_responsable, id_comprobante, id_chofer_responsable,
        id_doc_salida, id_tipo_origen,
        id_estado_actividad, observaciones,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        v_titulo, p_descripcion, p_fecha_programada,
        p_hora_inicio_estimada, p_hora_fin_estimada,
        p_id_tipo_actividad, p_id_prioridad, v_cliente,
        p_id_trabajador_responsable, p_id_comprobante,
        COALESCE(p_id_chofer_responsable, (SELECT id_chofer FROM doc_salida WHERE id = p_id_doc_salida)),
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



-- Function: age_actualizar_actividad
-- Source: migraciones/20260908_age_id_doc_salida_y_ordenes_disponibles.sql

DROP FUNCTION IF EXISTS age_actualizar_actividad(p_id integer, p_titulo character varying, p_descripcion text, p_fecha_programada date, p_hora_inicio_estimada time without time zone, p_hora_fin_estimada time without time zone, p_fecha_hora_cierre timestamp without time zone, p_id_tipo_actividad integer, p_id_prioridad integer, p_id_cliente integer, p_id_trabajador_responsable integer, p_id_estado_actividad integer, p_observaciones character varying, p_id_usuario_auditoria integer, p_id_comprobante integer, p_id_guia_remision integer, p_items json);

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
    p_items json DEFAULT NULL::json,
    p_id_chofer_responsable integer DEFAULT NULL
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

    -- ------------------------------------------------------------
    -- El formulario NO mueve el flujo operativo. EN_RUTA / REALIZADA /
    -- CANCELADA solo cambian por iniciar_entrega, culminar_entrega,
    -- cancelar o marcar realizada. Si el UPDATE aceptara cualquier
    -- id_estado_actividad, un EN_RUTA -> PENDIENTE dejaria cilindros en
    -- EN_TRANSITO sin viaje.
    -- ------------------------------------------------------------
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
        RETURN json_build_object('registro', NULL, 'error', 'El tipo de actividad indicado no es vÃ¡lido.');
    END IF;

    IF p_id_prioridad IS NOT NULL AND NOT EXISTS (
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

    -- El responsable de un reparto ya no tiene que ser chofer de flota propia:
    -- en la entrega suelen ir el chofer y alguien de apoyo, y cualquiera de los
    -- dos puede figurar como responsable. Se comprueba fuera del IF del tipo
    -- para que también valide cuando se cambia solo el responsable.
    IF p_id_trabajador_responsable IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM tra_trabajadores t
            WHERE t.id = p_id_trabajador_responsable AND t.estado = 1
        ) THEN
            RETURN json_build_object('registro', NULL, 'error', 'El responsable debe ser un trabajador vigente.');
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

    IF p_id_chofer_responsable IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_chofer WHERE id = p_id_chofer_responsable AND estado = 1
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El chofer seleccionado debe estar activo.');
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
        id_chofer_responsable = COALESCE(p_id_chofer_responsable, id_chofer_responsable, (SELECT id_chofer FROM doc_salida WHERE id = COALESCE(p_id_doc_salida, age_actividad.id_doc_salida))),
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

-- =============================================================================



-- Function: age_obtener_actividad
-- Synced from migracion 20260908_age_recojo_vencidos_fk.sql
--
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- el alquiler ya no tiene detalle de cilindros (bal_alquiler_detalle eliminada);
-- el origen ALQUILER expone solo el regulador/accesorio pendiente.

CREATE OR REPLACE FUNCTION age_obtener_actividad(p_id integer)
RETURNS json
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
    v_items JSON;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_detalle_origen JSON := NULL;
    v_tiene_items BOOLEAN;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON)
    INTO v_items
    FROM (
        SELECT
            i.id,
            i.item,
            i.id_producto,
            COALESCE(p.nombre, i.descripcion) AS nombre_producto,
            i.descripcion,
            i.cantidad,
            um.nombre AS nombre_unidad_medida,
            i.id_balon,
            b.codigo_balon,
            b.numero_serie AS numero_serie_balon,
            tb.nombre AS nombre_tipo_balon,
            b.id_producto_gas,
            COALESCE(pgb.nombre, p.nombre) AS nombre_producto_gas,
            i.id_estado_verificacion_salida,
            evs.nombre AS estado_verificacion_salida,
            i.observacion_salida,
            i.id_estado_verificacion_llegada,
            evl.nombre AS estado_verificacion_llegada,
            i.observacion_llegada,
            i.id_estado_producto_recogido,
            epr.nombre AS estado_producto_recogido,
            i.id_doc_salida_detalle,
            i.id_venta_detalle,
            i.id_prestamo_detalle
        FROM age_actividad_item i
        LEFT JOIN pro_producto p ON p.id = i.id_producto
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        LEFT JOIN bal_balon b ON b.id = i.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones evs ON evs.id = i.id_estado_verificacion_salida
        LEFT JOIN gen_lista_opciones evl ON evl.id = i.id_estado_verificacion_llegada
        LEFT JOIN gen_lista_opciones epr ON epr.id = i.id_estado_producto_recogido
        WHERE i.id_actividad = p_id AND i.estado = 1
    ) t;

    v_tiene_items := COALESCE(json_array_length(v_items), 0) > 0;

    SELECT act.id_prestamo, act.id_alquiler
    INTO v_id_prestamo, v_id_alquiler
    FROM age_actividad act
    WHERE act.id = p_id AND act.estado = 1;

    IF NOT v_tiene_items AND v_id_prestamo IS NOT NULL THEN
        SELECT json_build_object(
            'origen', 'PRESTAMO',
            'id_origen', p.id,
            'numero', p.numero_prestamo,
            'fecha_pactada', p.fecha_retorno_pactada,
            'cilindros', COALESCE((
                SELECT json_agg(row_to_json(c) ORDER BY c.id)
                FROM (
                    SELECT
                        pd.id,
                        pd.id_balon,
                        b.codigo_balon,
                        b.numero_serie AS numero_serie_balon,
                        tb.nombre AS nombre_tipo_balon,
                        COALESCE(pd.id_producto, b.id_producto_gas) AS id_producto,
                        COALESCE(pg.nombre, pgb.nombre) AS nombre_producto,
                        pgb.nombre AS nombre_producto_gas,
                        1::NUMERIC AS cantidad
                    FROM bal_prestamo_detalle pd
                    LEFT JOIN bal_balon b ON b.id = pd.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN pro_producto pg ON pg.id = pd.id_producto
                    LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
                    WHERE pd.id_prestamo = p.id
                      AND pd.estado = 1
                      AND pd.fecha_devolucion IS NULL
                      AND pd.id_balon IS NOT NULL
                ) c
            ), '[]'::JSON),
            'garantias', COALESCE((
                SELECT json_agg(row_to_json(g) ORDER BY g.id)
                FROM (
                    SELECT
                        vg.id,
                        vg.monto_saldo,
                        vg.monto_cobrado,
                        vg.monto_devuelto,
                        eg.nombre AS nombre_estado,
                        pr.nombre AS nombre_producto
                    FROM ven_garantia vg
                    LEFT JOIN gen_lista_opciones eg ON eg.id = vg.id_estado
                    LEFT JOIN pro_producto pr ON pr.id = vg.id_producto
                    WHERE vg.id_prestamo = p.id AND vg.estado = 1
                ) g
            ), '[]'::JSON)
        )
        INTO v_detalle_origen
        FROM bal_prestamo p
        WHERE p.id = v_id_prestamo;
    ELSIF NOT v_tiene_items AND v_id_alquiler IS NOT NULL THEN
        SELECT json_build_object(
            'origen', 'ALQUILER',
            'id_origen', a.id,
            'numero', a.numero_alquiler,
            'fecha_pactada', a.fecha_fin_pactada,
            -- El alquiler es solo del regulador/accesorio; el cilindro va por
            -- préstamo. Se mantiene la clave para el frontend, siempre vacía.
            'cilindros', '[]'::JSON,
            'garantias', COALESCE((
                SELECT json_agg(row_to_json(g) ORDER BY g.id)
                FROM (
                    SELECT
                        vg.id,
                        vg.monto_saldo,
                        vg.monto_cobrado,
                        vg.monto_devuelto,
                        eg.nombre AS nombre_estado,
                        pr.nombre AS nombre_producto
                    FROM ven_garantia vg
                    LEFT JOIN gen_lista_opciones eg ON eg.id = vg.id_estado
                    LEFT JOIN pro_producto pr ON pr.id = vg.id_producto
                    WHERE vg.id_alquiler = a.id AND vg.estado = 1
                ) g
            ), '[]'::JSON),
            'regulador', CASE
                WHEN COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL AND a.fecha_devolucion_regulador IS NULL
                THEN json_build_object(
                    'id_producto', COALESCE(a.id_producto_regulador, a.id_producto_stock),
                    'nombre_producto', COALESCE(pr.nombre, ps.nombre),
                    'codigo_producto', COALESCE(pr.codigo, ps.codigo),
                    'pendiente', TRUE
                )
                ELSE NULL
            END
        )
        INTO v_detalle_origen
        FROM bal_alquiler a
        LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
        LEFT JOIN pro_producto ps ON ps.id = a.id_producto_stock
        WHERE a.id = v_id_alquiler;
    END IF;

    SELECT row_to_json(t)
    INTO v_registro
    FROM (
        SELECT
            act.id,
            act.titulo,
            act.descripcion,
            act.fecha_programada,
            act.hora_inicio_estimada,
            act.hora_fin_estimada,
            act.fecha_hora_cierre,
            act.id_tipo_actividad,
            ta.nombre AS nombre_tipo_actividad,
            act.id_prioridad,
            pr.nombre AS nombre_prioridad,
            act.id_cliente,
            COALESCE(NULLIF(TRIM(c.razon_social), ''), NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''), c.numero_documento) AS razon_social_cliente,
            dir.latitud AS latitud_cliente,
            dir.longitud AS longitud_cliente,
            act.id_trabajador_responsable,
            TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)) AS nombre_trabajador_responsable,
            act.id_trabajador_apoyo,
            TRIM(CONCAT_WS(' ', ap.nombres, ap.apellido_paterno, ap.apellido_materno)) AS nombre_trabajador_apoyo,
            act.id_usuario_responsable,
            au.nombre AS nombre_usuario_responsable,
            ch.id AS id_chofer_responsable,
            NULLIF(TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)), '') AS nombre_chofer_responsable,
            COALESCE(act.id_comprobante, ds.id_venta) AS id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            cc.id AS id_comprobante_compra,
            cc.serie AS serie_comprobante_compra,
            cc.numero AS numero_comprobante_compra,
            act.id_doc_salida,
            ds.serie AS serie_doc_salida,
            ds.numero_sunat AS numero_sunat_doc_salida,
            ds.numero AS numero_doc_salida,
            act.id_prestamo,
            bp.numero_prestamo,
            bp.fecha_retorno_pactada AS fecha_retorno_pactada_prestamo,
            act.id_alquiler,
            ba.numero_alquiler,
            ba.fecha_fin_pactada AS fecha_fin_pactada_alquiler,
            act.id_tipo_origen,
            tor.nombre AS nombre_tipo_origen,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.observaciones,
            act.estado,
            act.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            act.id_usuario_modificacion,
            umod.nombre AS nombre_usuario_modificacion,
            act.fecha_creacion,
            act.fecha_modificacion,
            v_items AS items,
            v_detalle_origen AS detalle_origen
        FROM age_actividad act
        LEFT JOIN gen_lista_opciones ta
            ON ta.id = act.id_tipo_actividad
           AND ta.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'TipoActividad' OR gl.id = 48)
        LEFT JOIN gen_lista_opciones pr
            ON pr.id = act.id_prioridad
           AND pr.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'PrioridadActividad' OR gl.id = 50)
        LEFT JOIN gen_lista_opciones ea
            ON ea.id = act.id_estado_actividad
           AND ea.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'EstadoActividad' OR gl.id = 49)
        LEFT JOIN gen_lista_opciones tor ON tor.id = act.id_tipo_origen
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN LATERAL (
            SELECT cd.latitud, cd.longitud
            FROM cli_direcciones cd
            WHERE cd.id_cliente = act.id_cliente AND cd.estado = 1
            ORDER BY cd.es_principal DESC NULLS LAST, cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        LEFT JOIN tra_trabajadores tr ON tr.id = act.id_trabajador_responsable
        LEFT JOIN tra_trabajadores ap ON ap.id = act.id_trabajador_apoyo
        LEFT JOIN auth_usuarios au ON au.id_trabajador = tr.id AND au.estado = TRUE
        LEFT JOIN doc_salida ds ON act.id_doc_salida = ds.id
        LEFT JOIN LATERAL (
            SELECT ch0.* FROM gen_chofer ch0
            WHERE ch0.id = COALESCE(act.id_chofer_responsable, ds.id_chofer)
               OR (act.id_chofer_responsable IS NULL AND ds.id_chofer IS NULL AND ch0.id_trabajador = tr.id AND ch0.estado = 1)
            ORDER BY ch0.id LIMIT 1
        ) ch ON TRUE
        LEFT JOIN ven_comprobante vc ON vc.id = COALESCE(act.id_comprobante, ds.id_venta)
        LEFT JOIN LATERAL (
            SELECT compra.id, compra.serie, compra.numero FROM com_comprobante_compra compra
            WHERE compra.id = ds.id_comprobante_compra
               OR (ds.id_comprobante_compra IS NULL AND compra.id_doc_salida = ds.id AND compra.estado = 1)
            ORDER BY compra.id DESC LIMIT 1
        ) cc ON TRUE
        LEFT JOIN bal_prestamo bp ON bp.id = act.id_prestamo
        LEFT JOIN bal_alquiler ba ON ba.id = act.id_alquiler
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios umod ON act.id_usuario_modificacion = umod.id
        WHERE act.id = p_id AND act.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- Function: age_listar_actividades
-- Source: migraciones/20260908_age_id_doc_salida_y_ordenes_disponibles.sql

CREATE OR REPLACE FUNCTION age_listar_actividades(
    p_busqueda character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 10,
    p_offset integer DEFAULT 0,
    p_fecha_desde date DEFAULT NULL::date,
    p_fecha_hasta date DEFAULT NULL::date,
    p_id_estado integer DEFAULT NULL::integer,
    p_id_tipo integer DEFAULT NULL::integer,
    p_id_prioridad integer DEFAULT NULL::integer,
    p_sin_responsable boolean DEFAULT NULL::boolean
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM age_actividad act
    LEFT JOIN cli_clientes c ON act.id_cliente = c.id
    WHERE act.estado = 1
      AND (p_fecha_desde IS NULL OR act.fecha_programada >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR act.fecha_programada <= p_fecha_hasta)
      AND (p_id_estado IS NULL OR act.id_estado_actividad = p_id_estado)
      AND (p_id_tipo IS NULL OR act.id_tipo_actividad = p_id_tipo)
      AND (p_id_prioridad IS NULL OR act.id_prioridad = p_id_prioridad)
      AND (p_sin_responsable IS NULL OR (
          (p_sin_responsable AND act.id_trabajador_responsable IS NULL)
          OR (NOT p_sin_responsable AND act.id_trabajador_responsable IS NOT NULL)
      ))
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(act.titulo, p_busqueda)
          OR gen_texto_coincide(COALESCE(act.observaciones, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            act.id,
            act.titulo,
            act.descripcion,
            act.fecha_programada,
            act.hora_inicio_estimada,
            act.hora_fin_estimada,
            act.fecha_hora_cierre,
            act.id_tipo_actividad,
            ta.nombre AS nombre_tipo_actividad,
            act.id_prioridad,
            pr.nombre AS nombre_prioridad,
            act.id_cliente,
            COALESCE(NULLIF(TRIM(c.razon_social), ''), NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''), c.numero_documento) AS razon_social_cliente,
            act.id_trabajador_responsable,
            TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)) AS nombre_trabajador_responsable,
            act.id_trabajador_apoyo,
            TRIM(CONCAT_WS(' ', ap.nombres, ap.apellido_paterno, ap.apellido_materno)) AS nombre_trabajador_apoyo,
            act.id_usuario_responsable,
            au.nombre AS nombre_usuario_responsable,
            ch.id AS id_chofer_responsable,
            NULLIF(TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)), '') AS nombre_chofer_responsable,
            COALESCE(act.id_comprobante, ds.id_venta) AS id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            cc.id AS id_comprobante_compra,
            cc.serie AS serie_comprobante_compra,
            cc.numero AS numero_comprobante_compra,
            act.id_doc_salida,
            ds.serie AS serie_doc_salida,
            ds.numero_sunat AS numero_sunat_doc_salida,
            ds.numero AS numero_doc_salida,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.observaciones,
            act.fecha_creacion,
            act.fecha_modificacion,
            act.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            act.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM age_actividad act
        LEFT JOIN gen_lista_opciones ta
            ON ta.id = act.id_tipo_actividad
           AND ta.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'TipoActividad' OR gl.id = 48)
        LEFT JOIN gen_lista_opciones pr
            ON pr.id = act.id_prioridad
           AND pr.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'PrioridadActividad' OR gl.id = 50)
        LEFT JOIN gen_lista_opciones ea
            ON ea.id = act.id_estado_actividad
           AND ea.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'EstadoActividad' OR gl.id = 49)
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN tra_trabajadores tr ON tr.id = act.id_trabajador_responsable
        LEFT JOIN tra_trabajadores ap ON ap.id = act.id_trabajador_apoyo
        LEFT JOIN auth_usuarios au ON au.id_trabajador = tr.id AND au.estado = TRUE
        LEFT JOIN doc_salida ds ON act.id_doc_salida = ds.id
        LEFT JOIN LATERAL (
            SELECT ch0.* FROM gen_chofer ch0
            WHERE ch0.id = COALESCE(act.id_chofer_responsable, ds.id_chofer)
               OR (act.id_chofer_responsable IS NULL AND ds.id_chofer IS NULL AND ch0.id_trabajador = tr.id AND ch0.estado = 1)
            ORDER BY ch0.id LIMIT 1
        ) ch ON TRUE
        LEFT JOIN ven_comprobante vc ON vc.id = COALESCE(act.id_comprobante, ds.id_venta)
        LEFT JOIN LATERAL (
            SELECT compra.id, compra.serie, compra.numero FROM com_comprobante_compra compra
            WHERE compra.id = ds.id_comprobante_compra
               OR (ds.id_comprobante_compra IS NULL AND compra.id_doc_salida = ds.id AND compra.estado = 1)
            ORDER BY compra.id DESC LIMIT 1
        ) cc ON TRUE
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON act.id_usuario_modificacion = um.id
        WHERE act.estado = 1
          AND (p_fecha_desde IS NULL OR act.fecha_programada >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR act.fecha_programada <= p_fecha_hasta)
          AND (p_id_estado IS NULL OR act.id_estado_actividad = p_id_estado)
          AND (p_id_tipo IS NULL OR act.id_tipo_actividad = p_id_tipo)
          AND (p_id_prioridad IS NULL OR act.id_prioridad = p_id_prioridad)
          AND (p_sin_responsable IS NULL OR (
              (p_sin_responsable AND act.id_trabajador_responsable IS NULL)
              OR (NOT p_sin_responsable AND act.id_trabajador_responsable IS NOT NULL)
          ))
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(act.titulo, p_busqueda)
              OR gen_texto_coincide(COALESCE(act.observaciones, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
          )
        ORDER BY
            CASE
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) IN ('PENDIENTE', 'PROGRAMADA') THEN 0
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) IN ('CANCELADA', 'CANCELADO') THEN 2
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA' THEN 3
                ELSE 1
            END ASC,
            act.fecha_programada DESC,
            act.hora_inicio_estimada DESC NULLS LAST,
            act.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- =============================================================================


COMMIT;
